#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint plaid_omni_connect.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'plaid_omni_connect'
  s.version          = '0.0.1'
  s.summary          = 'Plaid Omni Connect Link integration for Flutter.'
  s.description      = <<-DESC
Plaid Omni Connect Link integration for Flutter with inline UX on iOS.
                       DESC
  s.homepage         = 'https://github.com/decodewest/plaid_omni_connect'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'DecodeWest' => 'email@example.com' }
  s.source           = { :path => '.' }
  s.source_files = 'plaid_omni_connect/Sources/plaid_omni_connect/**/*.swift'
  s.dependency 'Flutter'
  s.platform = :ios, '13.0'
  s.resource_bundles = {'plaid_omni_connect_privacy' => ['plaid_omni_connect/Sources/plaid_omni_connect/Resources/PrivacyInfo.xcprivacy']}

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'
end
