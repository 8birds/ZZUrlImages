Pod::Spec.new do |s|
  s.name             = 'ZZUrlImages'
  s.version          = '1.0.1'
  s.summary          = 'Load images to UIButtons and UIImageViews from an NSURL or NSURLRequest.'

  s.description      = <<-DESC
ZZURLImageButton is a UIButton that accepts URLs for any of the button states.
ZZURLImageView can be used similarly to load an image into the view.

NSURLRequests can also be used when more fine-grained control is needed over the network request.
                       DESC

  s.homepage         = 'https://github.com/8birds/zzurlimages'
  s.license          = { :type => 'Apache 2.0', :file => 'LICENSE' }
  s.author           = { 'Rick Kern' => 'rick@8birdsvideo.com' }
  s.source           = { :git => 'https://github.com/8birds/zzurlimages.git', :tag => s.version.to_s }

  s.ios.deployment_target = '10.0'

  s.source_files = 'zzurlimages/Classes/**/*'

  s.frameworks = 'UIKit'
  s.dependency 'ZZPromises', '~> 1.0'
  #s.dependency 'ZZDataStructures', :path => ../ZZDataStructures
end
