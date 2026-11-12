"""Non-destructive, stdlib-only builder logic regressions (no registry or GUI)."""
import importlib.util
import io
import subprocess
import hashlib
from unittest import mock
import json
from pathlib import Path
import tempfile
import unittest
import sys
import zipfile

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "scripts"))

def module(name, path):
    spec = importlib.util.spec_from_file_location(name, ROOT / path)
    item = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(item)
    return item

resolver = module('resolver_test', 'scripts/resolve_release.py')
adapter = module('adapter_test', 'scripts/apply_adapter.py')
package = module('package_test', 'scripts/package_native.py')
validator = module('validator_test', 'scripts/validate_native.py')

class StableReleaseTests(unittest.TestCase):
    def test_sort_numeric_not_lexicographic(self):
        releases = [
            {'tag_name':'v0.9.10','draft':False,'prerelease':False},
            {'tag_name':'v0.10.2','draft':False,'prerelease':False},
            {'tag_name':'v9.0.0-rc.1','draft':False,'prerelease':True},
            {'tag_name':'v99.0.0','draft':True,'prerelease':False},
        ]
        self.assertEqual(resolver.choose_release(releases)['tag_name'], 'v0.10.2')
        self.assertEqual(resolver.choose_release(releases,'0.9.10')['tag_name'], 'v0.9.10')
        with self.assertRaises(ValueError): resolver.choose_release(releases,'nightly')
        with self.assertRaises(ValueError): resolver.choose_release(releases,'9.0.0')
    def test_rejects_partial_versions(self):
        self.assertIsNone(resolver.stable_key('v1.2'))
        self.assertIsNone(resolver.stable_key('v1.2.3-beta'))

class PatchTests(unittest.TestCase):
    def test_adapter_is_precise_and_fails_closed(self):
        source = 'fn portable_dir() {\n' + adapter.BEFORE + '\n}'
        new = adapter.adapt(source)
        self.assertNotIn('writable.then_some(dir)', new)
        self.assertIn('Some(dir)', new)
        with self.assertRaises(RuntimeError): adapter.adapt(new)
        with self.assertRaises(RuntimeError): adapter.adapt(source + adapter.BEFORE)

class ArtifactTests(unittest.TestCase):
    def test_real_64bit_pe_structure_required(self):
        with tempfile.TemporaryDirectory() as tmp:
            f = Path(tmp) / 'fake.exe'
            f.write_bytes(b'not-an-exe')
            self.assertFalse(package.is_x64_pe(f))
            content = bytearray(300)
            content[:2]=b'MZ'
            content[0x3c:0x40]=(128).to_bytes(4,'little')
            content[128:132]=b'PE\0\0'
            content[132:134]=(0x8664).to_bytes(2,'little')
            f.write_bytes(content)
            self.assertTrue(package.is_x64_pe(f))
            self.assertTrue(validator.is_x64_pe_bytes(content))
            content[132:134]=(0x14c).to_bytes(2,'little')
            self.assertFalse(validator.is_x64_pe_bytes(content))
    def test_compact_patch_bundle_ignores_untracked_checkout_and_validates(self):
        if not __import__('shutil').which('git'):
            self.skipTest('git is unavailable')
        with tempfile.TemporaryDirectory() as temp:
            base = Path(temp)
            upstream = base/'upstream'
            upstream.mkdir()
            (upstream/'crates/ipc/src').mkdir(parents=True)
            original = 'pub fn portable_dir() {\n    None\n}\n'
            source = upstream/'crates/ipc/src/lib.rs'
            source.write_text(original, encoding='utf-8')
            (upstream/'Cargo.toml').write_text('[workspace.package]\nversion = "0.5.2"\n', encoding='utf-8')
            (upstream/'Cargo.lock').write_text('# pinned dependency lock\n', encoding='utf-8')
            (upstream/'LICENSE').write_text('GPL-3.0-or-later\n', encoding='utf-8')
            (upstream/'ATTRIBUTION.md').write_text('Test attribution\n', encoding='utf-8')
            def git(*argv):
                subprocess.run(['git','-C',str(upstream), *argv],check=True,
                               stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            git('init')
            git('config','user.name','Fixture')
            git('config','user.email','fixture@example.invalid')
            git('add','.')
            git('commit','-m','Fixture commit')
            sha = subprocess.check_output(['git','-C',str(upstream),'rev-parse','HEAD'], text=True).strip()
            source.write_text('pub fn portable_dir() {\n // Native portable fail-closed:\n Some(dir)\n}\n', encoding='utf-8')
            # This large output is intentionally untracked. The previous source packer
            # recursively included it in the 934 MB source asset.
            (upstream/'generated-download.tmp').write_bytes(b'X' * (5*1024*1024))
            binaries = upstream/'target/release'
            binaries.mkdir(parents=True)
            exe = bytearray(300)
            exe[:2] = b'MZ'
            exe[0x3c:0x40] = (128).to_bytes(4, 'little')
            exe[128:132] = b'PE\0\0'
            exe[132:134] = (0x8664).to_bytes(2, 'little')
            for name in package.BINARIES:
                (binaries/name).write_bytes(exe)
            chromium = upstream/'target/extension/chromium'
            chromium.mkdir(parents=True)
            (chromium/'manifest.json').write_text('{"name":"Mister Download Manager","manifest_version":3}', encoding='utf-8')
            with zipfile.ZipFile(upstream/'target/extension/mdm-firefox.xpi','w') as z:
                z.writestr('manifest.json','{"manifest_version":2,"name":"MDM"}')
            identity = {'version':'0.5.2', 'builder_revision':'b1r4',
                        'upstream_tag':'v0.5.2', 'upstream_sha':sha, 'build_mode':'NATIVE'}
            id_file = base/'build-identity.json'
            id_file.write_text(json.dumps(identity),encoding='utf-8')
            original_check_output = subprocess.check_output
            def fake_command(argv, *args, **kwargs):
                if argv[0] in ('rustc','cargo'):
                    return f'{argv[0]} 1.95.0'
                return original_check_output(argv,*args,**kwargs)
            with mock.patch.object(package.subprocess,'check_output', side_effect=fake_command), \
                 mock.patch('sys.argv',['package_native.py','--upstream',str(upstream),
                                         '--identity',str(id_file),'--output',str(base/'dist')]):
                package.main()
            app = base/'dist/MisterDownloadManager-0.5.2-NativePortable-b1r4.zip'
            patch = base/'dist/MisterDownloadManager-0.5.2-NativePortable-SOURCE-PATCH-b1r4.zip'
            self.assertTrue(app.is_file())
            self.assertTrue(patch.is_file())
            self.assertLess(patch.stat().st_size, 200_000)
            with zipfile.ZipFile(patch) as z:
                self.assertNotIn('generated-download.tmp', '\n'.join(z.namelist()))
                self.assertIn('MisterDownloadManager-Source-Patch/PORTABILITY.patch',z.namelist())
                self.assertIn('MisterDownloadManager-Source-Patch/UPSTREAM-SOURCE.txt',z.namelist())
                self.assertIn(sha, z.read('MisterDownloadManager-Source-Patch/UPSTREAM-SOURCE.txt').decode())
            validator.validate(app)

    def test_wrong_mode_zip_rejected(self):
        with tempfile.TemporaryDirectory() as tmp:
            p = Path(tmp) / 'sample.zip'
            with zipfile.ZipFile(p,'w') as z:
                z.writestr(package.ROOT_NAME+'/App/AppInfo/appinfo.ini','wrong-mode')
            with self.assertRaises(RuntimeError): validator.validate(p)

class SafetyTests(unittest.TestCase):
    def test_explicit_opt_in_and_no_registry_takeover(self):
        text = (ROOT/'portable_integration/Manager.ps1').read_text(encoding='utf-8')
        self.assertIn('Existing key belongs to another installation', text)
        self.assertIn('No ownership journal', text)
        self.assertIn('HKEY_CURRENT_USER', text)
        self.assertNotIn('Registry::HKEY_LOCAL_MACHINE', text)
        self.assertIn("'pending'", text)
        self.assertIn('Get-KeyDefault', text)
        self.assertIn('Unregister-Portable', text)
    def test_powershell_51_console_root_resolution(self):
        # Regression for Windows 5.1 param-default $PSScriptRoot returning an empty
        # string; that used to crash [IO.Path]::GetFullPath before the menu.
        for stem, cmd in (('Manager.ps1','Mister-Manager.cmd'),):
            ps = (ROOT/'portable_integration'/stem).read_text(encoding='utf-8')
            launcher = (ROOT/'portable_integration'/cmd).read_text(encoding='utf-8')
            self.assertNotIn('AppRoot=$PSScriptRoot', ps)
            self.assertNotIn('AppRoot = $PSScriptRoot', ps)
            self.assertIn("$PSCommandPath", ps)
            self.assertIn("$MyInvocation.MyCommand.Path", ps)
            self.assertIn("[string]::IsNullOrWhiteSpace($AppRoot)", ps)
            self.assertIn("GetDirectoryName([IO.Path]::GetFullPath($scriptFile))", ps)
            self.assertNotIn('-AppRoot', launcher)
            self.assertNotIn('-PortableRoot', launcher)
            self.assertIn('-Action Menu', launcher)
            self.assertIn('set "SCRIPT=%~dp0'+stem+'"', launcher)
            self.assertIn('-File "%SCRIPT%"', launcher)

    def test_one_unified_console_and_legacy_safeguards(self):
        scripts = sorted(p.name for p in (ROOT/'portable_integration').iterdir() if p.is_file())
        self.assertEqual(scripts, ['Manager.ps1', 'Mister-Manager.cmd'])
        manager = (ROOT/'portable_integration/Manager.ps1').read_text(encoding='utf-8')
        for required in ('Browser-Menu', 'Startup-Menu', 'Main-Menu',
                         'Get-RecordState', 'Register-Portable', 'Unregister-Portable',
                         'Remove-VerifiedLegacy', 'Print-Inventory', 'Get-KeyDetails',
                         'BACKUP-INDEX.json', '& $reg export', 'Legacy-Registry-Backups',
                         'LegacyScan', 'SelfTest', 'REMOVE LEGACY', 'REMOVE SYSTEM LEGACY',
                         'No ownership journal. Refusing to remove any registry entries.',
                         'ExpectedCommand', 'HKEY_CURRENT_USER'):
            self.assertIn(required, manager)
        self.assertIn("$BackupRoot = Join-Path $integration 'Legacy-Registry-Backups'", manager)
        self.assertIn('DoNotExpandEnvironmentNames', manager)
        self.assertIn('$parent.DeleteSubKey($HostName,$false)', manager)
        self.assertIn('MDM is running. Exit all MDM processes', manager)
        launcher = (ROOT/'portable_integration/Mister-Manager.cmd').read_text(encoding='ascii')
        self.assertIn('setlocal EnableExtensions DisableDelayedExpansion', launcher)
        self.assertIn('set "SCRIPT=%~dp0Manager.ps1"', launcher)
        self.assertNotIn(' -AppRoot ', launcher)
        self.assertNotIn(' -PortableRoot ', launcher)

    def test_package_requires_only_one_console(self):
        pkg = (ROOT/'scripts/package_native.py').read_text(encoding='utf-8')
        val = (ROOT/'scripts/validate_native.py').read_text(encoding='utf-8')
        self.assertIn("'portable_integration/Manager.ps1'", pkg)
        self.assertIn('unified_manager_sha256', pkg)
        self.assertNotIn('BrowserIntegration.ps1', pkg)
        self.assertIn("f'{ROOT_NAME}/Manager.ps1'", val)
        self.assertIn('Duplicate legacy console included', val)

    def test_source_distribution_and_existing_release_ownership(self):
        pack=(ROOT/'scripts/package_native.py').read_text(encoding='utf-8')
        self.assertIn('NativePortable-SOURCE-PATCH-',pack)
        self.assertIn('Source-Patch',pack)
        self.assertIn('actual_rustc',pack)
        published=(ROOT/'scripts/check_release.py').read_text(encoding='utf-8')
        self.assertIn('portable-release-publisher:managed:v2',published)
        self.assertIn('asset_names != expect',published)

    def test_no_unbounded_source_checkout_archive(self):
        pack = (ROOT/'scripts/package_native.py').read_text(encoding='utf-8')
        self.assertNotIn("checkout.rglob('*')", pack)
        self.assertIn("'git', '-C', str(checkout), 'diff', '--binary'", pack)
        self.assertIn('MAX_PATCH_ARCHIVE_BYTES', pack)
        self.assertIn('SOURCE-ACCESS.txt', pack)

    def test_no_wrong_mode_workflow(self):
        wf=(ROOT/'.github/workflows/build-native.yml').read_text(encoding='utf-8')
        self.assertNotIn('Portable-Package-Builder',wf)
        self.assertIn('cargo build --release --locked',wf)
        self.assertIn("dry-run: 'true'",wf)
        self.assertIn("dry-run: 'false'",wf)
        self.assertIn('SOURCE-PATCH-*.zip',wf)
        self.assertIn('MisterDownloadManager-Source-Patch/Cargo.lock',wf)
        self.assertIn('cb64f86ac2d8c67506db5832de07f9ff58cbeaeb',wf)

if __name__ == '__main__': unittest.main()
