Pod::Spec.new do |spec|

    spec.name                   = 'IRCSwiftyLapRF'
    spec.version                = '0.2'
    spec.summary                = 'ImmersionRC LapRF Comm Library'

    spec.homepage               = 'https://github.com/hydrafpv/irc-swifty-laprf'
    spec.license                = { :type => 'MIT', :file => 'LICENSE' }
    spec.author                 = { 'netizen01' => 'n01@invco.de' }

    spec.ios.deployment_target  = '10.2'
    spec.tvos.deployment_target = '11.2'
    spec.osx.deployment_target  = '10.13'

    spec.source                 = { :git => 'https://github.com/hydrafpv/irc-swifty-laprf.git',
                                    :tag => spec.version.to_s }

    spec.default_subspec        = 'Core'
    spec.swift_version          = '5.0'

    spec.subspec 'Core' do |core|
        core.source_files       = 'Source/Core/**/*.swift'
    end

    spec.subspec 'SwiftySensors' do |bluetooth|
        bluetooth.source_files  = 'Source/SwiftySensors/**/*.swift'
        bluetooth.dependency    'IRCSwiftyLapRF/Core'
        bluetooth.dependency    'SwiftySensors'
    end

    spec.subspec 'SerialUSB' do |serialUSB|
        serialUSB.source_files  = 'Source/SerialUSB/**/*.swift'
        serialUSB.dependency    'IRCSwiftyLapRF/Core'
        serialUSB.dependency    'ORSSerialPort'
    end

end
