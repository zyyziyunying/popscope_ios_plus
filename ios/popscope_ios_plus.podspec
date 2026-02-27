#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint popscope_ios_plus.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'popscope_ios_plus'
  s.version          = '0.1.3'
  s.summary          = 'Enhanced iOS pop gesture interceptor for Flutter.'
  s.description      = <<-DESC
Enhanced iOS pop gesture interceptor for Flutter. Provides fine-grained control over iOS left-edge swipe gestures with per-page callbacks, automatic cleanup, and better performance.
                       DESC
  s.homepage         = 'https://github.com/zyyziyunying/popscope_ios_plus'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'zyyziyunying' => 'zyyziyunying@163.com' }
  s.source           = { :path => '.' }
  s.source_files = 'popscope_ios/Sources/popscope_ios/**/*'
  s.dependency 'Flutter'
  s.platform = :ios, '13.0'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'

  # If your plugin requires a privacy manifest, for example if it uses any
  # required reason APIs, update the PrivacyInfo.xcprivacy file to describe your
  # plugin's privacy impact, and then uncomment this line. For more information,
  # see https://developer.apple.com/documentation/bundleresources/privacy_manifest_files
  # s.resource_bundles = {'popscope_ios_privacy' => ['popscope_ios/Sources/popscope_ios/PrivacyInfo.xcprivacy']}
end
