import UIKit
import CoreMotion
import Dispatch


class ViewController: UIViewController {

    private let activityManager = CMMotionActivityManager()
    private let pedometer = CMPedometer()
    private let motion = CMMotionManager()
    
    private var shouldStartUpdating: Bool = false
    private var startDate: Date? = nil

    @IBOutlet weak var startButton: UIButton!
    @IBOutlet weak var stepsCountLabel: UILabel!
    @IBOutlet weak var activityTypeLabel: UILabel!
    @IBOutlet weak var headingLabel: UILabel!
    @IBOutlet weak var userAcceleration: UILabel!
    @IBOutlet weak var pedometerEvent: UILabel!
    
    let documentsPath = NSSearchPathForDirectoriesInDomains(
        .documentDirectory, .userDomainMask, true)[0]
    //var url:NSURL
    //var writePath:NSURL?
    //var writePath:NSString

    private func writeToFile(content: String, fileName: String = "log.txt") {
        let contentWithNewLine = content+"\n"
        let filePath = NSHomeDirectory() + "/Documents/" + fileName
        let fileHandle = FileHandle(forWritingAtPath: filePath)
        if (fileHandle != nil) {
            fileHandle?.seekToEndOfFile()
            fileHandle?.write(contentWithNewLine.data(using: String.Encoding.utf8)!)
        }
        else {
            do {
                try contentWithNewLine.write(toFile: filePath, atomically: true, encoding: String.Encoding.utf8)
            } catch {
                print("Error while creating \(filePath)")
            }
        }
    }

    private func removeFile(fileName: String = "log.txt") {
        let filePath = NSHomeDirectory() + "/Documents/" + fileName
        let fileManager = FileManager.default
        do {
            if fileManager.fileExists(atPath: filePath) {
                // Delete file
                try fileManager.removeItem(atPath: filePath)
            } else {
                print("File does not exist")
            }
        }
        catch let error as NSError {
            print("An error took place: \(error)")
        }
        
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        removeFile()
        startButton.addTarget(self, action: #selector(didTapStartButton), for: .touchUpInside)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        guard let startDate = startDate else { return }
        updateStepsCountLabelUsing(startDate: startDate)
    }

    @objc private func didTapStartButton() {
        shouldStartUpdating = !shouldStartUpdating
        shouldStartUpdating ? (onStart()) : (onStop())
    }
}


extension ViewController {
    private func onStart() {
        startButton.setTitle("Stop", for: .normal)
        startDate = Date()
        checkAuthorizationStatus()
        startUpdating()
    }

    private func onStop() {
        startButton.setTitle("Start", for: .normal)
        startDate = nil
        stopUpdating()
    }

    private func startUpdating() {
        startQueuedUpdates()
        
        if CMMotionActivityManager.isActivityAvailable() {
            startTrackingActivityType()
        } else {
            activityTypeLabel.text = "Not available"
        }

        if CMPedometer.isStepCountingAvailable() {
            startCountingSteps()
        } else {
            stepsCountLabel.text = "Not available"
        }
    }

    private func checkAuthorizationStatus() {
        switch CMMotionActivityManager.authorizationStatus() {
        case CMAuthorizationStatus.denied:
            onStop()
            activityTypeLabel.text = "Not available"
            stepsCountLabel.text = "Not available"
        default:break
        }
    }

    private func stopUpdating() {
        activityManager.stopActivityUpdates()
        pedometer.stopUpdates()
        pedometer.stopEventUpdates()
        motion.stopDeviceMotionUpdates()
    }

    private func on(error: Error) {
        //handle error
    }

    private func updateStepsCountLabelUsing(startDate: Date) {
        pedometer.queryPedometerData(from: startDate, to: Date()) {
            [weak self] pedometerData, error in
            if let error = error {
                self?.on(error: error)
            } else if let pedometerData = pedometerData {
                DispatchQueue.main.async {
                    self?.stepsCountLabel.text = String(describing: pedometerData.numberOfSteps)
                }
            }
        }
    }
    
    private func startQueuedUpdates() {
        if motion.isDeviceMotionAvailable {       self.motion.deviceMotionUpdateInterval = 1.0 / 3.0
            self.motion.showsDeviceMovementDisplay = true
            self.motion.startDeviceMotionUpdates(
                using: .xMagneticNorthZVertical,
                 to: OperationQueue.main, withHandler: { (data, error) in
                    // Make sure the data is valid before accessing it.
                    if let validData = data {
                        // Get the attitude relative to the magnetic north reference frame.
                        let roll = validData.attitude.roll
                        let pitch = validData.attitude.pitch
                        let yaw = validData.attitude.yaw
                        let heading = validData.heading
                        let accel = validData.userAcceleration
                        let x = round(100*accel.x)/100
                        let y = round(100*accel.y)/100
                        let z = round(100*accel.z)/100
                        let a = round(100*sqrt(pow(accel.x,2) + pow(accel.y,2)))/100
                        let d = round(100*atan2(accel.y,accel.x))/100
                        DispatchQueue.main.async {
                            self.headingLabel.text = String(heading)
                            self.userAcceleration.text = String(a) + " " + String(d)
                            let formatter = DateFormatter()
                            // initially set the format based on your datepicker date / server String
                            formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
                            let myString = formatter.string(from: Date()) // string purpose I add here

                            self.writeToFile(content: "\(myString), HEADING, \(heading)")
                            self.writeToFile(content: "\(myString), ACCELMAGNITUDE, \(a)")
                            self.writeToFile(content: "\(myString), ACCELDIRECTION, \(d)")
                        }
                        
                        // Use the motion data in your app.
                    }
            })
        }
        else {
            DispatchQueue.main.async {
                self.headingLabel.text = "ITS NOT AVAILABLE"
            }
        }
    }
    
    private func startTrackingActivityType() {
        activityManager.startActivityUpdates(to: OperationQueue.main) {
            [weak self] (activity: CMMotionActivity?) in
            guard let activity = activity else { return }
            var actType: String = "init"
            DispatchQueue.main.async {
                if activity.walking {
                    actType = "Walking"
                } else if activity.stationary {
                    actType = "Stationary"
                } else if activity.running {
                    actType = "Running"
                } else if activity.automotive {
                    actType = "Automotive"
                }
                else {
                    actType = "Unknown"
                }
                self?.activityTypeLabel.text = actType
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
                let myString = formatter.string(from: Date()) // string purpose I add here
                self!.writeToFile(content: "\(myString), ACTIVITYTYPE, \(actType)")
            }
        }
    }

    private func startCountingSteps() {
        pedometer.startUpdates(from: Date()) {
            [weak self] pedometerData, error in
            guard let pedometerData = pedometerData, error == nil else { return }

            DispatchQueue.main.async {
                self?.stepsCountLabel.text = pedometerData.numberOfSteps.stringValue
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
                let myString = formatter.string(from: Date()) // string purpose I add here
                self!.writeToFile(content: "\(myString), STEPCOUNT, \(pedometerData.numberOfSteps.stringValue)")
            }
        }
        pedometer.startEventUpdates() {
            [weak self] pedometerEvent, error in
            guard let pedometerEvent = pedometerEvent, error == nil else { return }
            
            DispatchQueue.main.async {
                var pedEvent: String = "Notset"
                if pedometerEvent.type == CMPedometerEventType.pause {
                    pedEvent = "Pause"
                } else if pedometerEvent.type == CMPedometerEventType.resume {
                    pedEvent = "Resume"
                } else {
                    pedEvent = "Unknown"
                }
                self?.pedometerEvent.text = pedEvent
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
                let myString = formatter.string(from: Date()) // string purpose I add here
                self!.writeToFile(content: "\(myString), PEDOMETEREVENT, \(pedEvent)")
            }
        }
    }
}
