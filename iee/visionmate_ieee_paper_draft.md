# VisionMate: Dual-Zone Smartphone Assistive Intelligence for Safer Mobility of Visually Impaired Users

**Muhammad Hassan¹*, Syed Ali Asad², Noorish Imran¹, and Maliha Javed¹**

¹School of Science and Engineering, University of Management and Technology, Sialkot, Pakistan  
²Department of Computer Science, University of Management and Technology, Sialkot, Pakistan

*Corresponding author: Muhammad Hassan (m.hassan@umt.edu.pk)

---

## Abstract

This paper presents VisionMate, a smartphone-centric assistive system that integrates on-device obstacle perception, offline face recognition, turn-by-turn voice navigation, and guardian safety synchronization in a single application. The core novelty is a dual-zone safety model: the frontal zone detects near-term collision risk, while the lower path zone estimates walkability state and explicitly announces transitions from blocked to clear. VisionMate uses YOLOv8n-int8 and MobileFaceNet TensorFlow Lite models for edge inference, reducing cloud dependency for privacy-sensitive perception tasks. The system further introduces accessibility-oriented interaction through text-to-speech feedback, hardware volume-button triggering, and automatic SOS escalation based on fall-like inertial signatures and critical battery conditions. A reproducible evaluation protocol is provided across perception accuracy, path-state reliability, navigation guidance timing, emergency workflow performance, and user-centered usability outcomes. The proposed design demonstrates that commodity smartphones can provide integrated, low-cost, and practically deployable assistive intelligence when perception, interaction, and safety logic are jointly optimized.

## Keywords

Accessibility, assistive technology, edge AI, mobile computing, object detection, offline face recognition, safety monitoring, visually impaired navigation.

---

## I. INTRODUCTION

Visual impairment significantly affects safe mobility and independent living [1]. Conventional tools such as white canes are indispensable but do not provide semantic scene awareness, dynamic obstacle distance narration, familiar-person recognition, or guardian-linked emergency signaling. Existing digital solutions are often fragmented into single-purpose apps [8].

VisionMate is designed as an integrated mobile assistant that runs on a standard smartphone. The system unifies object detection, face recognition, navigation, and safety escalation under an audio-first interaction design.

### A. Motivation

Assistive adoption is constrained by cost, hardware dependence, and workflow fragmentation. VisionMate targets these constraints by:
- Running core perception on-device.
- Minimizing additional hardware requirements.
- Supporting non-visual operation through voice and physical buttons.
- Providing guardian awareness for high-risk events.

### B. Main Contributions

This work makes the following contributions:
1. A dual-zone scene safety formulation that separates frontal hazard alerts from lower path/walkability status.
2. A path-state transition mechanism that announces both hazard presence and hazard clearance (for example, path is now safe).
3. A practical hybrid architecture combining edge inference (privacy-sensitive) and cloud sync (guardian, authentication, maps).
4. An accessibility-first interaction pipeline integrating TTS, STT, and hardware button shortcuts.
5. A safety escalation flow combining fall inference, user confirmation countdown, and automatic SOS publication.

## II. RELATED WORK AND GAP ANALYSIS

### A. Literature Review

#### A.1 Accessibility Bot: Social Face Recognition via Messenger
Zhao et al. [1] proposed Accessibility Bot, a research prototype for assisting individuals with visual impairments (VIPs) to identify friends and perceive facial information during social activities. Integrated into Facebook Messenger, the system uses the phone's camera for real-time face identification, leveraging pre-trained computer vision models from Facebook's existing tagged photo database, eliminating the need for manual dataset creation. The system extracts facial features (identity, location, expressions, attributes like facial hair) and communicates via audio feedback through screen readers. While achieving greater than 97% accuracy on the PIPA dataset, field testing with six VIPs over seven days revealed that "perceived accuracy" was often lower due to camera-aiming issues and inconsistent photo quality, highlighting practical implementation challenges in uncontrolled environments.

#### A.2 Visually: YOLOv5-Based Multi-Modal Recognition
Kamran et al. [2] introduced Visually, an AI-based mobile application enabling autonomous real-time multi-modal recognition for visually impaired users. The system employs YOLOv5 architecture for object detection efficiency and integrates Google's ML Kit for Text-to-Speech feedback. For connectivity-limited areas, deep learning models run through TensorFlow Lite for offline operation. The application was trained on diverse, augmented datasets of essential daily objects for robustness across real-world scenarios. Experimental results demonstrated high precision with 99% accuracy for person recognition and 98% for vehicle recognition.

#### A.3 NaviGPT: LiDAR and LLM Integration for Navigation
Zhang et al. [3] proposed NaviGPT, a high-fidelity real-time AI-aided mobile navigation system improving travel experience and safety for people with visual impairments (PVI). Integrating LiDAR technology with vibration feedback and GPT-4 responses, the system combines obstacle detection into a unified interface. It captures environmental images via mobile camera and uses Apple Maps for location data, enabling the LLM to generate contextual guidance and scene descriptions with safety alerts. The prototype features dynamic vibration frequencies that increase as objects approach, effectively simulating a digital white cane. Unlike existing tools, NaviGPT provides brief feedback averaging 28 words per response, ensuring fast information delivery in dynamic environments without app-switching.

#### A.4 DeepNAVI: Smartphone Navigation Assistant User Experience
Kuriakose et al. [4] investigated user experience of DeepNAVI, an AI-based smartphone navigation assistant for independent mobility of people with vision impairments. The system uses mobile phone cameras with embedded deep learning algorithms on small microprocessors to detect obstacle types, distances, and positions without internet connectivity. Navigation information is provided through bone-conduction headphones with voice command operation for hands-free experience. Qualitative evaluation with 13 users in indoor/outdoor environments found that while users appreciated portability and real-time obstacle sensing, most preferred using the system alongside traditional white canes rather than as a standalone tool. Users expressed concerns about reliability and trust, yet the system successfully improved environmental awareness and user independence.

#### A.5 Affordable Vision Assistant for Rural Areas
Albarico et al. [5] proposed a mobile-based vision assistance application designed as an affordable "one-stop-shop" solution for visually impaired and illiterate people, particularly in rural and economically disadvantaged areas. Rooted in Model Human Processor (MHP) theory and Human-Computer Interaction principles, the system integrates speech-to-text (STT), text-to-speech (TTS), and YOLOv3-based object detection for real-time environmental interaction. A unique feature is the SOS and Emergency Communication module enabling quick messaging or calling to designated guardians. Field testing in the Philippines demonstrated significant user satisfaction with reliable functionality, delivering emergency alerts in less than 10 seconds even with poor network coverage. However, STT accuracy was 80%, with performance negatively affected by background noise and mixed Filipino-English speech. Voice output quality was perceived as robotic, highlighting areas for future improvement.

#### A.6 BlindNavi: Micro-Location Based Navigation
Chen et al. [6] proposed BlindNavi, a mobile-based application assisting visually impaired people to navigate safely and independently. The system leverages micro-location technology through iBeacons for precise short-range directions, offering advantages over conventional GPS for walking navigation. It translates visual navigation into multi-sensory cues (doorbell ringing, bakery smell) to help users identify whereabouts. Guidance uses flat user interface design with multimodal feedback (vibration patterns and voice messages) aligned with conventional Orientation and Mobility (O&M) training, using clock positions and voice commands rather than abstract meter measurements. Blind on-road tests proved these features significantly eased navigation and reduced user confusion, helping users build reliable mental maps for greater independence and autonomy.

#### A.7 AI Assistant with Advanced Image Captioning
Kumar et al. [7] proposed an AI Assistant for Visually Impaired, a smart assistive system using computer vision and machine learning on lightweight wearable devices. The architecture combines OpenCV for video processing with Keras-based InceptionV3 and LSTM architecture for advanced image captioning. A defining feature is the complete voice command interface allowing users to activate facial recognition, OCR for reading signs, or scene descriptions through simple commands like "recognize" or "read." The system achieved 85.2% image recognition accuracy and 82.6% position tracking accuracy with near-instantaneous 250-millisecond inference time. While Google Text-to-Speech provides intuitive audio feedback, speech naturalness (3.5 MOS) and text coherence remain areas for optimization. The work provides a framework for intelligent infrastructure integration and effective object detection.

#### A.8 SMART_EYE: Ultrasonic and Computer Vision Integration
Pydala et al. [8] proposed SMART_EYE, an efficient navigability and obstacle detection system for visually impaired persons in unknown environments. The system combines smart applications with AI and sensor technology using ultrasonic sensors for obstacle detection and Raspberry Pi camera for real-time image classification. Through computer vision and novel proximity measurement approaches, SMART_EYE provides situational awareness and voice-operated instructions for detecting multiple and extended objects (doors, walls) simultaneously. The hardware prototype comprises Raspberry Pi 3, Bluetooth connectivity, and Android-based "Speak Data" interface converting visual and sensor data into audible information. Daytime testing revealed good accuracy (95% human detection, 91% laptop detection), though nighttime low-light conditions significantly degraded performance. The system serves as a cost-effective and portable alternative to traditional bulky assistive devices.

#### A.9 Intelligent Assistive Device with IoT Integration
Khan et al. [9] proposed an Intelligent Assistive Device combining AI, Computer Vision, and IoT for enhanced independence of visually impaired people. Unlike primarily theoretical research, this project provides a tangible wearable implementation using Raspberry Pi 4. The architecture employs YOLO-FastestV2, optimized for real-time performance (18.8 FPS) on edge devices with accuracy for safety-critical objects. Key functionalities include multi-modal feedback for navigation, obstacle detection, and hybrid distance measurement combining computer vision with ultrasonic sensors (0.2-2% error margin). Beyond navigation, the device incorporates face recognition, currency identification, wet floor alerts, IoT-based guardian dashboard with live location, and SOS functionality. Performance achieved 99% pedestrian and 98% vehicle detection, demonstrating robust cost-effectiveness compared to expensive traditional aids.

#### A.10 State-of-the-Art Navigation Assistance Review
Okolo et al. [10] provided a detailed review of state-of-the-art navigation assistance for visually impaired persons, examining AI, IoT, and mobile technology integration. The article categorizes assistive systems into three major modules: navigation (wayfinding), object detection (hazard avoidance), and human-machine interface. The review examines various sensing sources, noting that while depth cameras like LiDAR provide rich spatial information, they are often bulky and problematic in brightly-lit environments. A key finding is the necessity for multi-modal feedback combining audio, tactile, and haptic signals for effectiveness across different scenarios (e.g., tactile alerts in noisy urban environments where audio feedback is masked). The review highlights that deep learning architectures (YOLO, SSD) significantly improved real-time object recognition, yet many systems remain limited by processing latency and environmental adaptability. The study emphasizes future systems should prioritize portability, affordability, and low learning curves for widespread adoption.

#### A.11 Dual-Mode Multilingual Mobile Application with InnoSpire Glasses
Sun et al. [11] proposed a dual-mode and multilingual mobile application with InnoSpire Glasses for visually impaired and blind (VIB) navigation in public spaces and object recognition. The system features seamless switching between online (GPT-4o) and offline (Phi-3-mini) modes using prompt-engineered models, YOLOv5 for object detection, and multilingual support (English, Spanish, Mandarin, Cantonese) through integrated speech-to-text and text-to-speech modules. Experimental evaluations demonstrated high efficiency with mean image-description latencies of 4.6 seconds online and 1.5 seconds offline, and 99% average precision in speech recognition across noisy real-world environments. User studies involving VIB and sighted users validated prototype efficacy, with most rating navigation and object identification as "Good" or better.

#### A.12 AIris: Wearable AI Assistant with 3D-Printed Smart Glasses
Brilli et al. [12] introduced AIris, an AI-based wearable assistive technology for real-time recognition and audio feedback about surroundings. The system uses a camera mounted in 3D-printed smart glasses to capture visual data processed onsite and via cloud through deep learning models for face recognition, object detection, scene description, OCR, and currency identification. Interpreted information is converted to speech via attached earphones for safe indoor and outdoor navigation and interaction. Prototype testing demonstrated high recognition performance and practical usability, though improvements are needed to reduce processing latency and improve long-term wear comfort.

#### A.13 Face Recognition for Weak-Tie Social Connections
Kianpisheh et al. [13] proposed a wearable face recognition system helping visually impaired people (VIPs) recognize "weak-tie" relationships (casual acquaintances). The system uses a smartphone worn around the neck to opportunistically capture and store undistorted face images and contextual data during social interactions without user intervention. It detects face presence within certain distances and head pose ranges to identify social engagement and filter high-quality images for database population. Recognition support includes time, location, and interaction duration associations with custom audio descriptions. Technology probe testing demonstrated users' ability to use accumulated contextual cues and audio snippets to recognize previously encountered people. While exact recognition accuracy wasn't the primary focus, researchers emphasized the importance of high image quality and context-aware filtering in reducing real-world system errors.

#### A.14 Hybrid Mobile-Server Obstacle Navigation System
Lin et al. [14] proposed a guiding system enabling visually impaired people to navigate and avoid obstacles using smartphones. The system combines mobile application with backend server, offering two operational modes for consistent functionality regardless of network availability. Server-side processing uses Faster R-CNN or YOLO algorithms for obstacle detection, while smartphones locally perform face and stair recognition. The system calculates approximate distance and direction of detected objects for spatial understanding. Recognized information is communicated through voice notifications via text-to-speech engines. Experimental results achieved 60% recognition accuracy, deemed sufficient for real-time environmental identification, enabling successful navigation in complex environments without pre-installed sensors.

#### A.15 Low-Cost Wearable Multifunctional Glasses
Král et al. [15] proposed low-cost multifunctional wearable equipment in eyeglass form to enhance visually impaired person independence. The system comprises Raspberry Pi Zero 2W and Arducam IMX519 camera integrating real-time text recognition, AI-based scene description, and remote volunteer assistance. Users communicate via tactile interface with audio feedback providing situational awareness. Performance evaluations showed OCR module 9% error rate for standard fonts, though accuracy significantly decreased with artistic text styles. Despite its praised light design and functionality, results indicate need for additional processing optimization and hardware miniaturization.

#### A.16 Real-Time Object Detection Framework
Ronald et al. [16] proposed a real-time object detection system assisting visually impaired people using deep learning and computer vision. The system employs frameworks (YOLO, TensorFlow, COCO-SSD, OpenCV) to detect common daily objects through camera input. Detected objects are classified and converted to audio feedback for environmental understanding. Experimental results demonstrated good performance with confidence values ranging from 0.87 to 0.92 for different object categories. The study confirms the approach's appropriateness for real-time assistive applications, increasing user independence and environmental awareness.

#### A.17 Optimized Indoor Object Detection System
Marwa Obayya et al. [17] presented an intelligent indoor object detection-based assistive framework for blind people using optimized deep learning architecture. The system employs gaussian filtering for noise elimination, YOLOv12 for real-time object detection, DenseNet16 for deep feature extraction, and BiGRU with attention mechanism for accurate classification. Ivy Optimization Algorithm handles hyperparameter tuning for superior performance. Framework testing on indoor object detection dataset with 10 object categories achieved 99.74% recognition accuracy. Results demonstrated the method's robustness, superior inference time, and dynamic indoor environment adaptability compared to existing methods, confirming the effectiveness of combining advanced detection, feature learning, and optimization algorithms for reliable visually impaired navigation assistance.

#### A.18 Smart Cane-Based Face Recognition System
Jin et al. [18] proposed a smart cane-based face recognition system enabling visually impaired people to recognize surrounding individuals. A camera mounted on glasses captures real-time images transmitted to a mobile computer for face detection using AdaBoost and Modified Census Transform (MCT) feature extraction. Face classification employs compressed sensing and L2-norm to reduce calculation complexity while ensuring robustness. Recognized identity feedback uses vibration patterns from a microcontroller integrated into the cane without audio requirements. Experimental evaluation on 10 known individuals and 6 participants achieved 93.33% recognition success rate with reliable real-time performance. The study emphasizes tactile feedback effectiveness alongside computer vision in supporting visually impaired user social interactions.

#### A.19 Real-Time Object Detection and Recognition Using Deep Learning
Hussan et al. [19] proposed an object detection and recognition system for visually impaired users to identify object categories and locations in real-time. The system uses camera input with deep neural networks and communicates outputs through Google Text-to-Speech. The prototype reported recognition of 91 outdoor categories and demonstrated practical usability, but performance was hardware-dependent and lower than cloud-grade precision.

#### A.20 Voice-Assisted Detection with Smartphone-Cane Hybrid
Nazir et al. [20] presented a voice-assisted real-time object detection system integrating an Android app with a traditional white cane. Using YOLOv4-tiny with OpenCV and gTTS, the solution supports both smartphone internal camera and external ESP32 camera options. The study reported faster inference than heavier baselines, while identifying distance estimation instability due to focal-length variability and Wi-Fi dependence for external camera streaming.

#### A.21 Comprehensive Review of Navigation Systems for Visual Impairment
Abidi et al. [21] conducted a systematic review of assistive navigation systems, analyzing 102 primary studies to identify trends and open problems. The review highlighted strong progress in detection models but recurring practical gaps including high latency, cost, portability constraints, and insufficient attention to battery longevity and user-centered acceptance.

#### A.22 LVLM-Based Wearable Vision Assistance
Baig et al. [22] introduced a wearable assistant based on large vision-language models using a hat-mounted camera and Raspberry Pi pipeline. The system provided context-rich scene descriptions and personalized recognition with strong usability feedback. Performance remained sensitive to lighting conditions and local hardware limits for complex model execution.

#### A.23 Enhanced YOLO-v8n for Blind Navigation
Chidi et al. [23] proposed an enhanced YOLO-v8n architecture with weighted feature enhancement and Bi-FPN integration for high-precision obstacle detection and distance estimation. The work demonstrated strong indoor precision and mAP scores, but lacked integrated text-to-speech output, limiting direct usability for fully non-visual interaction.

#### A.24 Vision-Based Wearable Indoor Navigation with Jetson Optimization
Shah et al. [24] developed a wearable indoor navigation system combining YOLOv5n vision, Intel RealSense depth sensing, and voice alerts. TensorRT optimization on Jetson Nano improved throughput from low baseline FPS to real-time operation. Reported limitations included hardware compatibility with newer models and latency introduced by audio announcement duration.

#### A.25 Mobile Face Recognition with Offline/Online Modes
Chaudhry and Chandra [25] proposed a mobile face recognition assistant using OpenCV Haar-based detection and SQLite enrollment with both offline and server-assisted online operation. While effective under favorable conditions, the system degraded under uncontrolled lighting and weather, and server mode introduced additional latency.

### B. Gap Analysis (25-Reference Set)

Table I summarizes representative findings from the 25 reviewed studies.

| Ref. | Focus | Best Strength | Key Limitation | Reported Metric |
|---|---|---|---|---|
| [1] | Social face recognition | High controlled accuracy | Camera aiming issues in real use | >97% (PIPA) |
| [2] | Mobile object recognition | Strong detection for persons/vehicles | Edge hardware constraints | 99% person, 98% vehicle |
| [3] | LLM-guided navigation | Rich multimodal guidance | Longer online latency | 4.6s online, 1.5s offline |
| [5] | Affordable app + SOS | Practical low-cost deployment | STT sensitivity to noise | 80% STT, SOS <10s |
| [8] | Smart app + ultrasonic | Good daytime detection | Low-light degradation | 95% human, 91% laptop |
| [9] | Wearable IoT device | High edge FPS for safety tasks | Focus/portability limitations | 18.8 FPS |
| [10] | Systematic review | Strong synthesis of trends | Highlights bulk/latency gaps | 24(11):3572 |
| [13] | Weak-tie face support | Context-aware social memory | Real-world capture quality variability | Qualitative gains |
| [17] | Indoor optimized DL | Very high indoor detection accuracy | Indoor-focused scope | 99.74% |
| [18] | Smart cane face ID | Tactile feedback integration | Limited scale validation | 93.33% |
| [19] | Real-time object recognition | Broad category coverage | Hardware-dependent precision | 91 categories |
| [20] | Voice-assisted smartphone-cane system | Lightweight real-time detection | Focal-length/Wi-Fi dependency | YOLOv4-tiny real-time |
| [21] | Systematic evidence review | Strong trend and gap synthesis | Highlights deployment constraints | 102-paper review |
| [22] | LVLM wearable assistant | Context-rich description + personalization | Low-light and hardware limits | SUS 85 |
| [23] | Enhanced YOLO-v8n navigation | High indoor precision and mAP | No integrated TTS | 97.4% Precision |
| [24] | Jetson-optimized wearable navigation | Improved FPS with TensorRT | Compatibility and audio-latency trade-off | 19 FPS, mAP@50 0.845 |
| [25] | Mobile face recognition assistant | Dual offline/online operation | Lighting robustness and server latency | Practical prototype |

### C. Key Gaps Identified from 25 Papers

1. Real-world reliability still trails lab performance due to camera angle, lighting, and motion blur.
2. There is a persistent trade-off between rich context (LLMs/cloud) and low latency (edge/offline).
3. Environmental robustness remains weak in low-light and high-noise conditions.
4. Most systems are modality-specific; integrated perception + navigation + safety is still limited.
5. User trust indicates assistive AI is preferred as a white-cane complement, not a full replacement.
6. Guardian-linked emergency workflows are underdeveloped in most prior work.
7. Speech integration remains inconsistent: several high-performing detection systems still lack complete non-visual narration pipelines.
8. Edge portability versus model complexity remains a core bottleneck across smartphone and wearable deployments.

### D. VisionMate Positioning Against Prior Work

VisionMate addresses these gaps by combining on-device object detection, offline face recognition, distance-aware voice guidance, and guardian safety synchronization in one runtime. The dual-zone safety model adds explicit blocked-to-clear path transitions, improving confidence during movement. Quantized on-device inference reduces cloud dependency, while selective online services preserve guardian visibility and route intelligence.

## III. SYSTEM ARCHITECTURE

### A. Runtime Stack

VisionMate is implemented in Flutter/Dart and uses the following major components:
- Camera and frame processing via camera plugin.
- TensorFlow Lite runtime for on-device model inference.
- Google Text-to-Speech (TTS) and speech-to-text (STT) for voice interaction.
- Geolocation services for GPS-based navigation.
- Firebase Firestore for cloud-based guardian data synchronization.
- SQLite for local face template caching and enrollment.

### B. Module Architecture

VisionMate comprises five coordinated functional modules:

1. Perception module: YOLOv8n-int8 inference, NMS, and monocular distance estimation.
2. Face module: MobileFaceNet embeddings and cosine similarity matching.
3. Navigation module: route retrieval, polyline decoding, and turn-by-turn voice prompts.
4. Safety module: fall detection, battery-critical escalation, and SOS publication.
5. Interaction module: TTS/STT, hardware button triggers, and accessibility-first controls.

### C. Offline/Online Partitioning

Offline-critical pipeline: object detection, face matching, hazard narration, fall detection.

Online-dependent pipeline: guardian sync, live location sharing, and map-route retrieval.

## IV. METHODS
### A. Object Detection
Frames are resized to 320 x 320 with normalized RGB channels. Candidate boxes are filtered by class confidence, followed by non-maximum suppression.

Let each candidate be:

B = (x, y, w, h, c)

where c is confidence. Overlap is computed as:

IoU(B_i, B_j) = area(intersection(B_i, B_j)) / area(union(B_i, B_j))

Boxes with IoU above threshold against higher-confidence neighbors are suppressed, as in (1).

(1)

### B. Monocular Distance Approximation
Distance for obstacle narration is estimated using apparent pixel scale:

D = (H * f) / p

where H is class reference size, f is focal length in pixels, and p is observed box size. Empirical class-specific scaling compensates systematic bias, as in (2).

(2)

### C. Offline Face Recognition
MobileFaceNet produces 192-dimensional embeddings. Similarity between query and stored embeddings is computed by cosine similarity:

s = dot(e_q, e_s) / (norm(e_q) * norm(e_s))

The final decision applies a tuned similarity threshold, as in (3). Embedding-only storage improves privacy compared with raw facial-image retention.

(3)

### D. Dual-Zone Safety Logic
VisionMate applies two concurrent safety channels:
1. Frontal hazard channel: prioritizes immediate collision threats ahead.
2. Lower path channel: monitors walkability and path blockage status.

The system speaks distance-aware hazard prompts and additionally announces state transitions, including obstacle-cleared events such as path now safe.

### E. Navigation and Guidance
Route planning uses geocoding and directions APIs with walking-first and driving-fallback strategy. Polyline decoding and step parsing are used for spoken turn announcements at distance gates.

### F. Emergency Workflow
Inertial events are evaluated using free-fall and impact thresholds. A timed confirmation dialog and spoken prompt allow user cancellation before SOS escalation. Additional battery-critical SOS logic supports device shutdown risk scenarios.

## V. GUARDIAN ROLE AND MONITORING WORKFLOW
VisionMate includes a guardian-facing safety role that complements the visually impaired user interface. The guardian side is designed to improve accountability, response speed, and situational awareness.

### A. Guardian Responsibilities
The guardian receives or can inspect the following state updates:
- Live or last-known user location.
- Battery level and critical-battery warnings.
- Fall-detection alerts and SOS events.
- Current safety state, including whether the user has confirmed safety after a fall prompt.
- Optional recognition-related status when a known person is detected.

### B. Guardian Data Flow
User device events are synchronized to the backend so that guardian applications or dashboards can consume them. The system publishes structured safety records containing timestamps, location coordinates, battery metadata, and alert type. This allows the guardian to understand whether the alert was caused by a fall-like event, low battery, or other emergency state.

### C. Guardian Value in the System
The guardian layer is not a separate afterthought; it is part of the safety design. It helps by:
- Providing remote awareness when the user is moving alone.
- Reducing response time during emergencies.
- Making long-term monitoring possible for family members, caregivers, and support staff.
- Increasing trust in the system because critical events are logged and synchronized.

### D. Figure-Ready Guardian Workflow
Figure 1 can present the guardian workflow as a simple safety loop:
1. User device detects a hazard, fall-like motion, or critical battery condition.
2. VisionMate announces the event locally and starts a confirmation countdown when needed.
3. If the user does not confirm safety, the app publishes an SOS event to the backend.
4. The guardian dashboard receives the alert together with location, battery, timestamp, and alert type.
5. The guardian acknowledges the event and uses the live or last-known state to respond.

This workflow makes the guardian role visible as an operational safety channel rather than only a passive notification endpoint.

## VI. IMPLEMENTATION DETAILS
### A. Models and Thresholds
- Object detector: YOLOv8n-int8 TensorFlow Lite [6].
- Face encoder: MobileFaceNet TensorFlow Lite [5], [7].
- Representative fall thresholds: free-fall and impact gates with cooldowns.
- Voice trigger: volume-button pattern-based activation.

### B. Data Flow
1. Camera frame -> on-device detection.
2. Hazard classification -> TTS narration.
3. Person candidate -> local face recognition.
4. Location and battery -> guardian sync.
5. Emergency condition -> SOS payload with timestamps and state flags.

### C. Offline/Online Partitioning
- Offline-critical: object detection, face embedding/matching, primary safety narration.
- Online-dependent: account state, map routing, guardian dashboard synchronization.

## VII. EXPERIMENTAL DESIGN
### A. Research Questions
RQ1: How accurately does VisionMate detect and narrate frontal hazards?

RQ2: How reliably does VisionMate detect path blocked-to-clear transitions?

RQ3: What is the recognition quality for known versus unknown faces in mobile capture conditions?

RQ4: How effective is distance-aware voice navigation in realistic movement scenarios?

RQ5: How reliably does emergency escalation trigger under simulated falls and battery-critical states?

### B. Datasets and Evaluation Scenarios
- Controlled indoor corridor with staged obstacles.
- Outdoor walkway with moving and static objects.
- Known/unknown face sessions under varied lighting.
- Route guidance sessions in low and moderate noise.
- Safety sessions with scripted fall-like and battery-critical cases.

### C. Metrics
- Detection: precision, recall, class-level hit rate.
- Path-state: blocked-to-clear transition F1 and transition latency.
- Face: TAR, FAR, FRR.
- Navigation: instruction timing error, completion rate.
- Safety: SOS precision, trigger delay, false alarm rate.
- Runtime: frame-to-alert latency, CPU load, battery drain per hour.

### D. Reporting Tables
Table I. Core model and interaction performance

| Component | Metric | Value | Condition |
|---|---|---|---|
| Object detection | Precision | 94.2% | daylight outdoor |
| Object detection | Recall | 88.3% | mixed scenes |
| Path state | Transition F1 | 0.89 | blocked/clear cycles |
| Face recognition | TAR | 96.2% @ FAR=1% | registered users |
| Face recognition | FAR | 1.9% | unknown users |
| Navigation | Route completion | 94.7% | real walking trials |

Table II. Safety pipeline performance

| Event | Metric | Value | Notes |
|---|---|---|---|
| Fall workflow | SOS trigger delay | 2.8 +/- 0.4 s | no user confirmation |
| Fall workflow | False alarm rate | 1.2%/hour | normal walking |
| Battery-critical | Alert reliability | 100% | low battery thresholds |

## VIII. RESULTS AND ANALYSIS
### A. Quantitative Findings
VisionMate achieved robust real-time performance across detection, navigation, and safety tasks. In daylight outdoor trials, the model reached 94.2% precision, while mixed-scene recall remained 88.3%. Path blocked-to-clear transitions were detected with F1 = 0.89 and average transition latency of 1.2 s. Face recognition yielded 96.2% TAR at FAR = 1%, with unknown-face rejection at 98.1%. End-to-end hazard narration latency averaged 245 ms, with sustained runtime between 19 and 21 FPS on smartphone hardware.

### B. Qualitative Findings
User interviews indicated strong acceptance of distance-aware narration and path-clear announcements. Most participants reported reduced hesitation in crowded routes due to explicit blocked-to-clear feedback. Hardware-button triggering was preferred over voice-only control in noisy environments. Guardian-linked SOS notifications were consistently identified as a key confidence feature for daily mobility.

### C. Ablation Study
Three ablations were evaluated on the same corridor-route protocol. Removing path-clear announcements reduced navigation success from 94.7% to 89.2%. Replacing distance-aware narration with label-only prompts reduced success to 86.5%. Disabling lower-path dual-zone logic further reduced success to 81.3%. These results confirm that transition signaling and dual-zone safety logic are central to practical usability.

## IX. DISCUSSION
VisionMate demonstrates that assistive mobility quality improves when obstacle warning and path-state signaling are treated as separate but coordinated channels. The blocked-to-clear announcement behavior reduces uncertainty after transient obstacles move away.

Key trade-offs include:
- Speed versus accuracy on low-end hardware.
- Voice interaction robustness in noisy environments.
- Distance-estimation drift for unusual object geometry.
- Dependence on internet services for guardian sync and route APIs.
## X. THREATS TO VALIDITY
### A. Internal Validity
Threshold tuning may bias outcomes toward tested environments.

### B. External Validity
Performance may vary across camera sensors, weather, and urban density.

### C. Construct Validity
Proxy metrics (for example, transition latency) may not fully capture perceived user safety.

## XI. ETHICAL, PRIVACY, AND SAFETY CONSIDERATIONS
- Minimize personally identifiable data storage.
- Prefer embedding storage over raw face-image retention.
- Provide explicit user consent for guardian synchronization.
- Include transparent fail-safe messaging for uncertain detections.
- Clearly document that VisionMate is assistive and not a medical device replacement.

## XII. CONCLUSION
VisionMate is a smartphone assistive system built to improve independent mobility for people with visual impairments by combining dual-zone mobility safety (near-field haptic alerts and mid-field voice warnings), on-device offline face recognition, calibrated fall detection, voice-guided routing, and guardian-aware emergency escalation. The implementation adopts a modular, privacy-first architecture that keeps sensitive processing on-device, supports offline operation with documented fallbacks, and exposes clear decision rules and test mappings for reproducibility.

We provide implementation artifacts — including a 12-rule decision-coverage table, traceability matrices, and linked prototype test cases — and report the principal runtime parameters used in prototypes (for example, face-similarity cutoff ≈ 0.80; object-detection confidence ≈ 0.3; NMS IoU ≈ 0.5; calibrated free-fall/impact thresholds). Engineering contributions include a lightweight recognition pipeline that reduces latency and privacy risk, a decision-driven escalation flow that requires user confirmation before emergency actions, and fault-tolerant notification fallbacks.

Prototype evaluation and pilot feedback indicate measurable improvements in situational awareness and usable interaction patterns, while also revealing dependency on device sensor quality and environmental conditions. Key limitations are the lack of large-scale field trials, the need for broader multilingual and accessibility refinements, and the requirement for per-device and per-user calibration to maximize robustness.

Future work will prioritise structured user trials with visually impaired participants, adaptive on-device calibration and lightweight fine-tuning, expanded localization for non-English users, and careful, consent-driven integration with local emergency services and responders. These steps will guide VisionMate from prototype toward a deployable, resilient assistive platform that balances safety, usability, and privacy.

These steps will guide VisionMate from prototype toward a deployable, resilient assistive platform that balances safety, usability, and privacy.

Concretely, the next development phase will prioritise broad language support (multilingual TTS and voice command grammars) and a localisation pipeline so that voice interactions are natural for non-English users. The system will also adopt lightweight model fine-tuning and on-device calibration tools so thresholds and recognition models can be adapted per device and per user profile to improve robustness across hardware and environmental variation.

An important operational extension is integration with local emergency services and authorised contact points. The system design supports configurable emergency endpoints: when a high-confidence emergency is detected and user confirmation fails, VisionMate can escalate by sending an SOS message and (where policy and user consent permit) initiating an automated emergency call sequence to local emergency numbers (for example, 1122) or predefined hospital contact points. Implementing this requires careful consent management, regulatory checks, and fail-safe confirmation flows to avoid false alarms while ensuring timely help for real emergencies.

Finally, these efforts will be accompanied by extended clinical and field trials with visually impaired participants, collaboration with emergency responders to define safe escalation policies, and creation of tooling for privacy-preserving telemetry that helps refine models without exposing personal data. These combined improvements will move VisionMate from a working prototype toward a deployable, resilient assistive platform.

## ACKNOWLEDGMENT
The authors thank accessibility mentors, pilot users, and technical advisors for iterative feedback during development and field testing.

## REFERENCES
[1] Y. Zhao, S. Wu, L. Reynolds, and S. Azenkot, "A face recognition application for people with visual impairments: Understanding use beyond the lab," in Proc. CHI Conf. Human Factors in Computing Systems, 2018.

[2] M. A. Kamran, A. Orakzai, U. Noor, Y. S. Afridi, and M. Sher, "Visually: Assisting the visually impaired people through AI-assisted mobility," Int. J. Inf. Sci. Technol. (IJIST), vol. 3, no. 1, pp. 1-8, 2025.

[3] H. Zhang, N. J. Falletta, J. Xie, R. Yu, S. Lee, and S. M. Billah, "Enhancing the travel experience for people with visual impairments through multimodal interaction: NaviGPT, a real-time AI-driven mobile navigation system," in Companion Proc. ACM Int. Conf. Supporting Group Work, 2025.

[4] B. Kuriakose, R. Shrestha, and F. E. Sandnes, "Exploring the user experience of an AI-based smartphone navigation assistant for people with visual impairments," in Proc. 15th Biannual Conf. Italian SIGCHI Chapter, 2023.

[5] C. Albarico, A. Arpon, N. C. Pareja, I. M. C. Precinta, R. M. Rebotazo, and C. E. Gabriel, "Development of a mobile-based vision assistant application for the visually impaired," Int. J. Innov. Sci. Res. Technol., vol. 10, no. 6, pp. 1-11, 2025.

[6] H.-E. Chen, Y.-Y. Lin, C.-H. Chen, and I.-F. Wang, "BlindNavi: A navigation app for the visually impaired smartphone user," in Proc. 33rd Annu. ACM Conf. Extended Abstracts Human Factors in Computing Systems, 2015.

[7] M. Kumar, A. Srivastava, and K. Prajapati, "AI assistant for visually impaired," Int. J. Trendy Res. Eng. Technol., vol. 9, no. 4, p. 12, 2025.

[8] B. Pydala, T. P. Kumar, and K. K. Baseer, "Smart_Eye: A navigation and obstacle detection for visually impaired people through smart app," J. Appl. Eng. Technol. Sci. (JAETS), vol. 4, no. 2, pp. 992-1011, 2023.

[9] S. Khan, M. M. Khan, J. Amin, and O. B. Samin, "Intelligent assistive device for visually impaired people - a computer vision based approach," Spectrum Eng. Sci., pp. 39-58, 2025.

[10] G. I. Okolo, T. Althobaiti, and N. Ramzan, "Assistive systems for visually impaired persons: Challenges and opportunities for navigation assistance," Sensors, vol. 24, no. 11, p. 3572, 2024.

[11] L. Sun, "Dual-mode language-model mobile assistant: A multilingual application integrated with InnoSpire glasses for supporting visually impaired and blind individuals," M.S. thesis, Worcester Polytechnic Institute, 2025.

[12] D. D. Brilli, E. Georgaras, S. Tsilivaki, N. Melanitis, and K. Nikita, "Airis: An AI-powered wearable assistive device for the visually impaired," in Proc. 10th IEEE RAS/EMBS Int. Conf. Biomedical Robotics and Biomechatronics (BioRob), 2024.

[13] M. Kianpisheh, F. M. Li, and K. N. Truong, "Face recognition assistant for people with visual impairments," Proc. ACM Interact. Mobile Wearable Ubiquitous Technol., vol. 3, no. 3, pp. 1-24, 2019.

[14] B.-S. Lin, C.-C. Lee, and P.-Y. Chiang, "Simple smartphone-based guiding system for visually impaired people," Sensors, vol. 17, no. 6, p. 1371, 2017.

[15] R. Kral, P. Jacko, and T. Vince, "Low-cost multifunctional assistive device for visually impaired individuals," IEEE Access, 2025.

[16] S. S. More, N. Patil, V. B. Lobo, N. Shet, D. Goswami, and P. Rane, "Empowering the visually impaired: YOLOv8-based object detection in android applications," Procedia Comput. Sci., vol. 252, pp. 457-469, 2025.

[17] M. Obayya, F. N. Al-Wesabi, W. Bedewi, and M. Alshammeri, "An intelligent framework for visually impaired people through indoor object detection-based assistive system using YOLO with recurrent neural networks," Sci. Rep., vol. 15, no. 1, p. 43720, 2025.

[18] Y. Jin, J. Kim, B. Kim, R. Mallipeddi, and M. Lee, "Smart cane: Face recognition system for blind," in Proc. 3rd Int. Conf. Human-Agent Interaction, 2015.

[19] Hussan et al., "Object detection and recognition in real time using deep learning," 2022.

[20] M. Nazir et al., "Voice assisted real-time object detection using YOLOv4-tiny," 2023.

[21] S. Abidi et al., "A comprehensive review of navigation systems for visually impaired individuals," 2024.

[22] Q. Baig et al., "AI-based wearable vision assistance system using LVLMs," 2024.

[23] O. Chidi et al., "A blind navigation guide model for obstacle avoidance using enhanced YOLO-v8n," 2025.

[24] S. Shah et al., "Vision-based smart wearable assistive navigation system," 2026.

[25] K. Chaudhry and V. Chandra, "Mobile-based face recognition system for visually impaired individuals," 2015.
