install! 'cocoapods', :deterministic_uuids => false


platform :ios, '8.4'
use_frameworks!

# ignore all warnings from all pods
inhibit_all_warnings!

source 'git@github.com:CocoaPods/Specs.git'

# CE Internal
def import_common_dependencies

    #pod 'CocoaHTTPServer'

    # 3rd Party Dependencies
    pod 'CocoaAsyncSocket'
    pod 'CocoaAsyncSocket/RunLoop'
end

target :'AVAssetLoadValuesAsyncTest' do
    import_common_dependencies
end

