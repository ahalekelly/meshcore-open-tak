# AV1 still images for VOX photo messages on macOS and iOS
# (lib/vox/av1_ffi.dart finds vox_av1_encode/decode in the process). libaom is
# prebuilt by CI: aom-apple/ for macOS (universal arm64 + x86_64), aom-ios/
# for iPhone (arm64); see .github/workflows/build.yml. Without it, a stub
# builds instead and photos are reported as unavailable.
has_mac_aom = File.exist?(File.join(__dir__, 'aom-apple', 'lib', 'libaom.a'))
has_ios_aom = File.exist?(File.join(__dir__, 'aom-ios', 'lib', 'libaom.a'))

Pod::Spec.new do |s|
  s.name             = 'vox_av1'
  s.version          = '1.0.0'
  s.summary          = 'AV1 still images (libaom) for MeshCore Open TAK photo messages'
  s.homepage         = 'https://aomedia.org'
  s.license          = { :type => 'BSD-2-Clause' }
  s.author           = { 'MeshCore Open TAK' => 'noreply@example.invalid' }
  s.source           = { :path => '.' }
  s.osx.deployment_target = '10.15'
  s.ios.deployment_target = '12.0'
  s.compiler_flags   = '-std=gnu11'
  s.preserve_paths   = 'aom-apple/**/*', 'aom-ios/**/*', 'stub/*'
  if has_mac_aom
    s.osx.source_files        = 'vox_av1.c'
    s.osx.vendored_libraries  = 'aom-apple/lib/libaom.a'
    s.osx.pod_target_xcconfig = {
      'HEADER_SEARCH_PATHS' => '"$(PODS_TARGET_SRCROOT)/aom-apple/include"',
    }
  else
    s.osx.source_files = 'stub/vox_av1_stub.c'
  end
  if has_ios_aom
    s.ios.source_files        = 'vox_av1.c'
    s.ios.vendored_libraries  = 'aom-ios/lib/libaom.a'
    s.ios.pod_target_xcconfig = {
      'HEADER_SEARCH_PATHS' => '"$(PODS_TARGET_SRCROOT)/aom-ios/include"',
    }
  else
    s.ios.source_files = 'stub/vox_av1_stub.c'
  end
  s.libraries = 'm'
end
