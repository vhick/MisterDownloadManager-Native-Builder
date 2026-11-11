"""Non-destructive, stdlib-only builder logic regressions (no registry or GUI)."""
import importlib.util
import io
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
    def test_wrong_mode_zip_rejected(self):
        with tempfile.TemporaryDirectory() as tmp:
            p = Path(tmp) / 'sample.zip'
            with zipfile.ZipFile(p,'w') as z:
                z.writestr(package.ROOT_NAME+'/App/AppInfo/appinfo.ini','wrong-mode')
            with self.assertRaises(RuntimeError): validator.validate(p)

class SafetyTests(unittest.TestCase):
    def test_explicit_opt_in_and_no_registry_takeover(self):
        text = (ROOT/'portable_integration/BrowserIntegration.ps1').read_text(encoding='utf-8')
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
        for stem, cmd in (('BrowserIntegration.ps1','Mister-Browser-Integration.cmd'),
                          ('Manager.ps1','Mister-Manager.cmd')):
            ps = (ROOT/'portable_integration'/stem).read_text(encoding='utf-8')
            launcher = (ROOT/'portable_integration'/cmd).read_text(encoding='utf-8')
            self.assertNotIn('AppRoot=$PSScriptRoot', ps)
            self.assertNotIn('AppRoot = $PSScriptRoot', ps)
            self.assertIn("$PSCommandPath", ps)
            self.assertIn("$MyInvocation.MyCommand.Path", ps)
            self.assertIn("[string]::IsNullOrWhiteSpace($AppRoot)", ps)
            self.assertIn("GetDirectoryName([IO.Path]::GetFullPath($scriptFile))", ps)
            self.assertIn('-AppRoot "%~dp0."', launcher)
            self.assertIn('-File "%~dp0'+stem+'"', launcher)

    def test_source_distribution_and_existing_release_ownership(self):
        pack=(ROOT/'scripts/package_native.py').read_text(encoding='utf-8')
        self.assertIn('NativePortable-SOURCE-',pack)
        self.assertIn('Modified-Source',pack)
        self.assertIn('actual_rustc',pack)
        published=(ROOT/'scripts/check_release.py').read_text(encoding='utf-8')
        self.assertIn('portable-release-publisher:managed:v2',published)
        self.assertIn('asset_names != expect',published)

    def test_no_wrong_mode_workflow(self):
        wf=(ROOT/'.github/workflows/build-native.yml').read_text(encoding='utf-8')
        self.assertNotIn('Portable-Package-Builder',wf)
        self.assertIn('cargo build --release --locked',wf)
        self.assertIn("dry-run: 'true'",wf)
        self.assertIn("dry-run: 'false'",wf)
        self.assertIn('SOURCE-*.zip',wf)
        self.assertIn('MisterDownloadManager-Modified-Source/upstream/Cargo.lock',wf)
        self.assertIn('cb64f86ac2d8c67506db5832de07f9ff58cbeaeb',wf)

if __name__ == '__main__': unittest.main()
