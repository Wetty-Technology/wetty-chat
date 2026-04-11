Pod::Spec.new do |s|
  s.name             = 'voice_message'
  s.version          = '0.0.1'
  s.summary          = 'OGG/Opus transcoding and waveform extraction.'
  s.description      = <<-DESC
Flutter plugin for OGG/Opus to M4A/AAC transcoding and audio waveform extraction
using vendored swift-ogg source.
                       DESC
  s.homepage         = 'https://github.com/aspect-build/voice_message'
  s.license          = { :type => 'Apache-2.0', :file => '../LICENSE' }
  s.author           = { 'Codetector' => 'codetector@codetector.org' }
  s.source           = { :path => '.' }

  s.source_files     = 'Classes/**/*.{swift,c,h}'
  s.public_header_files = 'Classes/COpusOggBridge/include/**/*.h'
  s.preserve_paths   = 'Classes/COpusOggBridge/include/module.modulemap'

  s.ios.dependency 'Flutter'
  s.osx.dependency 'FlutterMacOS'
  s.ios.deployment_target = '13.0'
  s.osx.deployment_target = '10.15'

  s.dependency 'libopus/float'
  s.dependency 'libogg', '~> 1.3'

  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'SWIFT_INCLUDE_PATHS' => '$(PODS_TARGET_SRCROOT)/Classes/COpusOggBridge/include',
  }
  s.swift_version = '5.0'
end
