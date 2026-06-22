<a href="https://developer.apple.com/swift/"> 
  <img src="https://raw.githubusercontent.com/CardinalJV/CardinalJV/main/assets/logo-swift/swift-96x96_2x.png" alt="Logo Swift" title="Swift" width="68.5" height="68.5"/></a>
<a href="https://developer.apple.com/xcode/swiftui/"> 
  <img src="https://raw.githubusercontent.com/CardinalJV/CardinalJV/main/assets/logo-swift/swiftui-96x96_2x.png" alt="Logo SwiftUI" title="SwiftUI" width="68.5" height="68.5"/></a>
<a href="https://developer.apple.com/machine-learning/create-ml/"> 
  <img src="https://raw.githubusercontent.com/CardinalJV/CardinalJV/main/assets/logo-swift/create-ml-96x96_2x.png" alt="Logo Create ML" title="Create ML" width="68.5" height="68.5"/></a>
<a href="https://developer.apple.com/machine-learning/core-ml/">
  <img src="https://raw.githubusercontent.com/CardinalJV/CardinalJV/main/assets/logo-swift/core-ml-96x96_2x.png" alt="Logo CoreML" title="CoreML" width="68.5" height="68.5"/></a>

# SignReader 

SignReader is an iOS app that lets you interact with the sign language alphabet in real time — simply sign letters in front of your camera and watch them come together to form words, powered by a custom-trained recognition model fine-tuned for accuracy and responsiveness.

## Screencast

https://github.com/user-attachments/assets/96cf5e30-42bc-4a14-b252-ea4e5dd4b3b1

## Features

* Real-time hand sign detection:
    The app uses the camera to continuously analyze hand signs as they are performed. There is no need to pause, validate, or manually confirm each letter. The model processes the video stream in real time and immediately attempts to recognize the current sign.
* Letter-by-letter word construction:
    Each detected sign is converted into a letter and automatically added to the current word. This allows users to spell words naturally, one sign at a time, without interrupting the interaction flow.
* Custom-trained recognition model:
    I trained a machine learning model specifically for sign language letter recognition. The model was built and fine-tuned using a dedicated dataset so it could learn the visual differences between each letter of the alphabet.
* Model weakness identification and improvement:
    After testing the first versions of the model, I analyzed its weaknesses and identified signs that were often confused or poorly recognized. This helped me understand where the model lacked accuracy and which letters needed more training examples.
* Dataset enhancement with custom data:
    To improve the model’s performance, I added my own data to the training dataset. By collecting additional examples, especially for the signs that were harder to detect, I was able to make the model more reliable and better adapted to real usage conditions.
* Improved accuracy across different conditions:
    The model was improved to better handle variations such as different hand shapes, skin tones, camera angles, and lighting environments. This makes the recognition system more robust and usable in more realistic situations.
* Full alphabet support:
    The app supports all 26 letters of the sign language alphabet, allowing users to form any word by combining recognized letters.
* Instant visual feedback:
    Recognized letters are displayed immediately on screen, giving users clear feedback about what the app detects. This helps users correct their hand position if needed and makes the interaction easier to follow.

## Technical details

- Langages : Swift
- Frameworks : SwiftUI
- SDK : CoreML
- Architecture : MVVM
- Version iOS : iOS 26

## Installation 

Clone the project from the GitHub repository, then open it in Xcode. Make sure you're using the latest version of Xcode to avoid any compatibility issues.

## Credits

Thanks to Nazanin for being my guinea pig
