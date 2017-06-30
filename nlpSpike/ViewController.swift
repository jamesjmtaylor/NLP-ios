//
//  ViewController.swift
//  nlpSpike
//
//  Created by Taylor, James on 6/29/17.
//  Copyright © 2017 Taylor, James. All rights reserved.
//

import UIKit
import Speech

class ViewController: UIViewController, SFSpeechRecognizerDelegate {

    @IBOutlet weak var textView: UILabel!
    @IBOutlet var startRecordingButton: UIButton! {
        willSet {
            newValue.isEnabled = false
            newValue.setTitle("Start voice recording", for: .normal)
        }
    }
    
    lazy var speechRecognizer: SFSpeechRecognizer? = {
        if let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US")) {
            recognizer.delegate = self
            return recognizer
        }
        else { return nil }
    }()
    lazy var audioEngine: AVAudioEngine = {
        let audioEngine = AVAudioEngine()
        return audioEngine
    }()
    var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    var recognitionTask: SFSpeechRecognitionTask?
    
    let taggerOptions: NSLinguisticTagger.Options = [.joinNames, .omitWhitespace]
    lazy var linguisticTagger: NSLinguisticTagger = {
        let tagSchemes = NSLinguisticTagger.availableTagSchemes(forLanguage: "en")
        return NSLinguisticTagger(tagSchemes: tagSchemes, options: Int(self.taggerOptions.rawValue))
    }()
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        SFSpeechRecognizer.requestAuthorization { (authStatus: SFSpeechRecognizerAuthorizationStatus) in
            
            DispatchQueue.main.async {
                switch authStatus {
                case .authorized:
                    self.startRecordingButton.isEnabled = true
                case .denied:
                    self.startRecordingButton.isEnabled = false
                    self.startRecordingButton.setTitle("User denied access to speech recognition", for: .disabled)
                case .restricted:
                    self.startRecordingButton.isEnabled = false
                    self.startRecordingButton.setTitle("Speech recognition restricted on this device", for: .disabled)
                case .notDetermined:
                    self.startRecordingButton.isEnabled = false
                    self.startRecordingButton.setTitle("Speech recognition not yet authorized", for: .disabled)
                }
            }
        }

    }

    @IBAction func startRecordingButtonPressed() {
        if audioEngine.isRunning {
            audioEngine.stop()
            recognitionRequest?.endAudio()
            startRecordingButton.isEnabled = false
            startRecordingButton.setTitle("Stopping", for: .disabled)
        } else {
            try! startRecording()
            startRecordingButton.setTitle("Stop recording", for: [])
        }
    }

    // MARK: - Speech recognition methods
    private func startRecording() throws {
        if let recognitionTask = self.recognitionTask {  // Cancel the previous task if it's running.
            recognitionTask.cancel()
            self.recognitionTask = nil
        }
        // Create a new audio session
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(AVAudioSessionCategoryRecord)
        try audioSession.setMode(AVAudioSessionModeMeasurement)
        try audioSession.setActive(true, with: .notifyOthersOnDeactivation)
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest() // Create a new live recognition request
        guard let inputNode = audioEngine.inputNode else { fatalError("Audio engine has no input node") } // Get the audio engine input node
        guard let recognitionRequest = self.recognitionRequest else { fatalError("Unable to create a SFSpeechAudioBufferRecognitionRequest object") }
        recognitionRequest.shouldReportPartialResults = true // Configure request so that results are returned before audio recording is finished
        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { result, error in // A recognition task represents a speech recognition session.
            var isFinal = false
            if let result = result {  // When the recognizer returns a result, pass it to linguistic tagger
                let sentence = result.bestTranscription.formattedString
                self.linguisticTagger.string = sentence
                self.textView.text = sentence
                self.linguisticTagger.enumerateTags(in: NSMakeRange(0, (sentence as NSString).length), scheme: NSLinguisticTagSchemeNameTypeOrLexicalClass, options: self.taggerOptions) { (tag, tokenRange, _, _) in
                    let token = (sentence as NSString).substring(with: tokenRange)
                    print("\(token) -> \(tag)")
                }
                isFinal = result.isFinal
            }
            if error != nil || isFinal {
                self.audioEngine.stop()
                inputNode.removeTap(onBus: 0)
                self.recognitionRequest = nil
                self.recognitionTask = nil
                self.startRecordingButton.isEnabled = true
                self.startRecordingButton.setTitle("Start Recording", for: [])
            }
        }
        
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { (buffer: AVAudioPCMBuffer, when: AVAudioTime) in
            self.recognitionRequest?.append(buffer)
        }
        audioEngine.prepare() // Prepare the audio engine to allocate resources
        try audioEngine.start() // Start the audio engine
        textView.text = "(Go ahead, I'm listening)"
    }

}

