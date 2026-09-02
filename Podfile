platform :ios, '18.0'

project 'TimeNest.xcodeproj'
workspace 'TimeNest.xcworkspace'

target 'TimeNest' do
  use_frameworks! :linkage => :static

  # Microsoft-owned CocoaPod; keep the exact version for reproducible OCR builds.
  pod 'onnxruntime-objc', '1.29.0'

  target 'TimeNestTests' do
    inherit! :search_paths
  end
end

post_install do |installer|
  installer.pods_project.targets.each do |target|
    next unless target.name == 'onnxruntime-objc'

    target.build_configurations.each do |configuration|
      # Required for the official ORT Objective-C framework headers under Xcode 26.3.
      # See microsoft/onnxruntime#27717. This changes no model/runtime behavior.
      configuration.build_settings['CLANG_WARN_QUOTED_INCLUDE_IN_FRAMEWORK_HEADER'] = 'NO'
    end
  end
end
