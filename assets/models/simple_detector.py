# Simplified object detector - without actual TFLite
# Ye Flutter app ko basic detections dekh sakta hai

class SimpleDetector:
    def __init__(self):
        self.labels = ['person', 'car', 'dog', 'tree', 'bike', 'bus', 'cat', 'bird']
    
    def detect(self, image_path):
        # Simulated detections for testing
        return [
            {'label': 'person', 'confidence': 0.92, 'x': 50, 'y': 50, 'w': 150, 'h': 200},
            {'label': 'car', 'confidence': 0.88, 'x': 250, 'y': 150, 'w': 200, 'h': 120},
        ]

if __name__ == '__main__':
    detector = SimpleDetector()
    results = detector.detect('test.jpg')
    print("Detections:", results)
