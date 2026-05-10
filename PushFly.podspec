Pod::Spec.new do |s|
  s.name              = 'PushFly'
  s.version           = '0.1.0'
  s.summary           = 'Official PushFly SDK for native iOS apps.'
  s.description       = <<-DESC
    PushFly is the companion iOS SDK for the PushFly push notification
    service. It handles APNs enrollment, device registration, topic
    subscriptions, and notification delivery callbacks so apps can get
    push working in a few lines of code.
  DESC
  s.homepage          = 'https://pushfly.example.com/'
  s.license           = { :type => 'Apache-2.0', :file => 'LICENSE' }
  s.author            = { 'PushFly' => 'support@pushfly.example.com' }

  s.platform              = :ios
  s.ios.deployment_target = '13.0'
  s.swift_version         = '5.9'

  s.source            = { :git => 'https://github.com/pushfly/pushfly-sdk-ios.git', :tag => s.version.to_s }
  s.source_files      = 'Sources/PushFly/**/*.swift'
end
