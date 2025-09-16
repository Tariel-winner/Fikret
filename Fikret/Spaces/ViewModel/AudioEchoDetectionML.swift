import Foundation
import CoreML
import AVFoundation
import Accelerate

// MARK: - Audio Echo Detection using Machine Learning
class AudioEchoDetectionML: NSObject {
    
    // MARK: - Properties
    private var mlModel: MLModel?
    private let audioQueue = DispatchQueue(label: "com.fikret.ml.audio", qos: .userInitiated)
    private let sampleRate: Int = 16000 // Wav2Vec2 standard sample rate
    private let windowSize: Int = 1024
    private let hopSize: Int = 512
    
    // Audio feature extraction
    private var melSpectrogramExtractor: MelSpectrogramExtractor?
    private var mfccExtractor: MFCCExtractor?
    
    // Echo detection thresholds
    private let echoConfidenceThreshold: Float = 0.7
    private let realSpeechConfidenceThreshold: Float = 0.8
    
    // Safety thresholds to prevent accidental muting
    private let minimumVoicePreservation: Float = 0.15  // Never reduce below this level
    private let maximumEchoReduction: Float = 0.85      // Never reduce more than 85%
    
    // MARK: - Initialization
    override init() {
        super.init()
        setupMLModel()
        setupFeatureExtractors()
    }
    
    // MARK: - ML Model Setup
    private func setupMLModel() {
        // Try to load a pre-trained model for audio classification
        // For now, we'll use a custom model structure that can be trained
        setupCustomEchoDetectionModel()
    }
    
    private func setupCustomEchoDetectionModel() {
        // Create a simple neural network for echo detection
        // This can be replaced with a pre-trained Core ML model
        print("🤖 Setting up custom echo detection ML model")
    }
    
    private func setupFeatureExtractors() {
        melSpectrogramExtractor = MelSpectrogramExtractor(
            sampleRate: sampleRate,
            windowSize: windowSize,
            hopSize: hopSize
        )
        
        mfccExtractor = MFCCExtractor(
            sampleRate: sampleRate,
            windowSize: windowSize,
            hopSize: hopSize
        )
    }
    
    // MARK: - Main Echo Detection Method
    func detectEcho(
        primaryAudio: [Float],
        secondaryAudio: [Float],
        completion: @escaping (EchoDetectionResult) -> Void
    ) {
        audioQueue.async { [weak self] in
            guard let self = self else { return }
            
            let result = self.performEchoDetection(
                primaryAudio: primaryAudio,
                secondaryAudio: secondaryAudio
            )
            
            DispatchQueue.main.async {
                completion(result)
            }
        }
    }
    
    // MARK: - Core Echo Detection Logic
    private func performEchoDetection(
        primaryAudio: [Float],
        secondaryAudio: [Float]
    ) -> EchoDetectionResult {
        
        // 1. Extract audio features
        let primaryFeatures = extractAudioFeatures(from: primaryAudio)
        let secondaryFeatures = extractAudioFeatures(from: secondaryAudio)
        
        // 2. Calculate correlation and similarity metrics
        let correlation = calculateCorrelation(primaryFeatures, secondaryFeatures)
        let spectralSimilarity = calculateSpectralSimilarity(primaryFeatures, secondaryFeatures)
        let temporalAlignment = calculateTemporalAlignment(primaryAudio, secondaryAudio)
        
        // 3. Use ML model for classification
        let mlPrediction = classifyWithML(
            primaryFeatures: primaryFeatures,
            secondaryFeatures: secondaryFeatures,
            correlation: correlation,
            spectralSimilarity: spectralSimilarity,
            temporalAlignment: temporalAlignment
        )
        
        // 4. Combine traditional and ML approaches
        let finalResult = combineDetectionMethods(
            mlPrediction: mlPrediction,
            correlation: correlation,
            spectralSimilarity: spectralSimilarity,
            temporalAlignment: temporalAlignment
        )
        
        return finalResult
    }
    
    // MARK: - Feature Extraction
    private func extractAudioFeatures(from audio: [Float]) -> AudioFeatures {
        var features = AudioFeatures()
        
        // Extract MFCC features
        if let mfcc = mfccExtractor?.extractMFCC(from: audio) {
            features.mfccCoefficients = mfcc
        }
        
        // Extract Mel spectrogram
        if let melSpectrogram = melSpectrogramExtractor?.extractMelSpectrogram(from: audio) {
            features.melSpectrogram = melSpectrogram
        }
        
        // Extract statistical features
        features.statisticalFeatures = extractStatisticalFeatures(from: audio)
        
        // Extract spectral features
        features.spectralFeatures = extractSpectralFeatures(from: audio)
        
        return features
    }
    
    private func extractStatisticalFeatures(from audio: [Float]) -> StatisticalFeatures {
        var features = StatisticalFeatures()
        
        // RMS Energy
        features.rmsEnergy = sqrt(audio.map { $0 * $0 }.reduce(0, +) / Float(audio.count))
        
        // Zero Crossing Rate
        features.zeroCrossingRate = calculateZeroCrossingRate(audio)
        
        // Spectral Centroid
        features.spectralCentroid = calculateSpectralCentroid(audio)
        
        // Spectral Rolloff
        features.spectralRolloff = calculateSpectralRolloff(audio)
        
        // Spectral Bandwidth
        features.spectralBandwidth = calculateSpectralBandwidth(audio)
        
        return features
    }
    
    private func extractSpectralFeatures(from audio: [Float]) -> SpectralFeatures {
        var features = SpectralFeatures()
        
        // FFT
        let fft = performFFT(audio)
        features.magnitudeSpectrum = fft.magnitude
        features.phaseSpectrum = fft.phase
        
        // Spectral flux
        features.spectralFlux = calculateSpectralFlux(fft.magnitude)
        
        return features
    }
    
    // MARK: - ML Classification
    private func classifyWithML(
        primaryFeatures: AudioFeatures,
        secondaryFeatures: AudioFeatures,
        correlation: Float,
        spectralSimilarity: Float,
        temporalAlignment: Float
    ) -> MLPrediction {
        
        // Create input features for ML model
        let inputFeatures = createMLInputFeatures(
            primaryFeatures: primaryFeatures,
            secondaryFeatures: secondaryFeatures,
            correlation: correlation,
            spectralSimilarity: spectralSimilarity,
            temporalAlignment: temporalAlignment
        )
        
        // For now, use a rule-based approach that mimics ML
        // This can be replaced with actual Core ML model inference
        return performRuleBasedClassification(inputFeatures: inputFeatures)
    }
    
    private func createMLInputFeatures(
        primaryFeatures: AudioFeatures,
        secondaryFeatures: AudioFeatures,
        correlation: Float,
        spectralSimilarity: Float,
        temporalAlignment: Float
    ) -> MLInputFeatures {
        
        var inputFeatures = MLInputFeatures()
        
        // Combine all features into a single vector
        inputFeatures.featureVector = [
            correlation,
            spectralSimilarity,
            temporalAlignment,
            primaryFeatures.statisticalFeatures.rmsEnergy,
            secondaryFeatures.statisticalFeatures.rmsEnergy,
            primaryFeatures.statisticalFeatures.spectralCentroid,
            secondaryFeatures.statisticalFeatures.spectralCentroid,
            // Add more features as needed
        ]
        
        return inputFeatures
    }
    
    private func performRuleBasedClassification(inputFeatures: MLInputFeatures) -> MLPrediction {
        // This simulates ML model output
        // In a real implementation, this would be replaced with actual model inference
        
        let features = inputFeatures.featureVector
        guard features.count >= 7 else {
            return MLPrediction(echoProbability: 0.5, realSpeechProbability: 0.5, confidence: 0.0)
        }
        
        let correlation = features[0]
        let spectralSimilarity = features[1]
        let temporalAlignment = features[2]
        let primaryRMS = features[3]
        let secondaryRMS = features[4]
        
        // Rule-based classification logic
        var echoScore: Float = 0.0
        var realSpeechScore: Float = 0.0
        
        // High correlation suggests echo
        if correlation > 0.8 {
            echoScore += 0.4
        } else if correlation < 0.3 {
            realSpeechScore += 0.3
        }
        
        // High spectral similarity suggests echo
        if spectralSimilarity > 0.9 {
            echoScore += 0.3
        } else if spectralSimilarity < 0.5 {
            realSpeechScore += 0.3
        }
        
        // Good temporal alignment suggests echo
        if temporalAlignment > 0.8 {
            echoScore += 0.2
        }
        
        // Similar RMS levels suggest echo
        let rmsDifference = abs(primaryRMS - secondaryRMS)
        if rmsDifference < 0.1 {
            echoScore += 0.1
        } else {
            realSpeechScore += 0.2
        }
        
        // Normalize scores
        let totalScore = echoScore + realSpeechScore
        if totalScore > 0 {
            echoScore /= totalScore
            realSpeechScore /= totalScore
        }
        
        let confidence = max(echoScore, realSpeechScore)
        
        return MLPrediction(
            echoProbability: echoScore,
            realSpeechProbability: realSpeechScore,
            confidence: confidence
        )
    }
    
    // MARK: - Result Combination
    private func combineDetectionMethods(
        mlPrediction: MLPrediction,
        correlation: Float,
        spectralSimilarity: Float,
        temporalAlignment: Float
    ) -> EchoDetectionResult {
        
        // Weight the different approaches
        let mlWeight: Float = 0.6
        let traditionalWeight: Float = 0.4
        
        // Traditional approach score
        let traditionalEchoScore = (correlation + spectralSimilarity + temporalAlignment) / 3.0
        let traditionalRealSpeechScore = 1.0 - traditionalEchoScore
        
        // Combined score
        let combinedEchoScore = mlPrediction.echoProbability * mlWeight + traditionalEchoScore * traditionalWeight
        let combinedRealSpeechScore = mlPrediction.realSpeechProbability * mlWeight + traditionalRealSpeechScore * traditionalWeight
        
        // Apply safety constraints to prevent accidental muting
        let safeEchoScore = min(combinedEchoScore, maximumEchoReduction)
        let safeRealSpeechScore = max(combinedRealSpeechScore, minimumVoicePreservation)
        
        // Determine final classification with safety checks
        let isEcho = safeEchoScore > echoConfidenceThreshold
        let isRealSpeech = safeRealSpeechScore > realSpeechConfidenceThreshold
        
        // Ensure we don't accidentally mute real speech
        let finalEchoScore = isRealSpeech ? min(safeEchoScore, 0.3) : safeEchoScore
        let finalRealSpeechScore = isRealSpeech ? safeRealSpeechScore : max(safeRealSpeechScore, 0.2)
        
        let confidence = max(finalEchoScore, finalRealSpeechScore)
        
        return EchoDetectionResult(
            isEcho: isEcho,
            isRealSpeech: isRealSpeech,
            echoConfidence: finalEchoScore,
            realSpeechConfidence: finalRealSpeechScore,
            overallConfidence: confidence,
            mlPrediction: mlPrediction,
            correlation: correlation,
            spectralSimilarity: spectralSimilarity,
            temporalAlignment: temporalAlignment
        )
    }
    
    // MARK: - Utility Methods
    private func calculateCorrelation(_ features1: AudioFeatures, _ features2: AudioFeatures) -> Float {
        // Calculate correlation between MFCC coefficients
        guard let mfcc1 = features1.mfccCoefficients,
              let mfcc2 = features2.mfccCoefficients,
              mfcc1.count == mfcc2.count else {
            return 0.0
        }
        
        return calculatePearsonCorrelation(mfcc1, mfcc2)
    }
    
    private func calculateSpectralSimilarity(_ features1: AudioFeatures, _ features2: AudioFeatures) -> Float {
        // Calculate similarity between mel spectrograms
        guard let mel1 = features1.melSpectrogram,
              let mel2 = features2.melSpectrogram else {
            return 0.0
        }
        
        return calculateCosineSimilarity(mel1, mel2)
    }
    
    private func calculateTemporalAlignment(_ audio1: [Float], _ audio2: [Float]) -> Float {
        // Calculate temporal alignment using cross-correlation
        return calculateCrossCorrelation(audio1, audio2)
    }
    
    // MARK: - Mathematical Calculations
    private func calculatePearsonCorrelation(_ array1: [Float], _ array2: [Float]) -> Float {
        guard array1.count == array2.count && array1.count > 0 else { return 0.0 }
        
        let mean1 = array1.reduce(0, +) / Float(array1.count)
        let mean2 = array2.reduce(0, +) / Float(array2.count)
        
        var numerator: Float = 0.0
        var denominator1: Float = 0.0
        var denominator2: Float = 0.0
        
        for i in 0..<array1.count {
            let diff1 = array1[i] - mean1
            let diff2 = array2[i] - mean2
            
            numerator += diff1 * diff2
            denominator1 += diff1 * diff1
            denominator2 += diff2 * diff2
        }
        
        let denominator = sqrt(denominator1 * denominator2)
        return denominator > 0 ? numerator / denominator : 0.0
    }
    
    private func calculateCosineSimilarity(_ array1: [Float], _ array2: [Float]) -> Float {
        guard array1.count == array2.count && array1.count > 0 else { return 0.0 }
        
        var dotProduct: Float = 0.0
        var norm1: Float = 0.0
        var norm2: Float = 0.0
        
        for i in 0..<array1.count {
            dotProduct += array1[i] * array2[i]
            norm1 += array1[i] * array1[i]
            norm2 += array2[i] * array2[i]
        }
        
        let denominator = sqrt(norm1) * sqrt(norm2)
        return denominator > 0 ? dotProduct / denominator : 0.0
    }
    
    private func calculateCrossCorrelation(_ array1: [Float], _ array2: [Float]) -> Float {
        // Simplified cross-correlation calculation
        let minLength = min(array1.count, array2.count)
        guard minLength > 0 else { return 0.0 }
        
        var maxCorrelation: Float = 0.0
        
        for lag in -minLength/4..<minLength/4 {
            var correlation: Float = 0.0
            var count = 0
            
            for i in 0..<minLength {
                let index1 = i
                let index2 = i + lag
                
                if index2 >= 0 && index2 < minLength {
                    correlation += array1[index1] * array2[index2]
                    count += 1
                }
            }
            
            if count > 0 {
                correlation /= Float(count)
                maxCorrelation = max(maxCorrelation, abs(correlation))
            }
        }
        
        return maxCorrelation
    }
    
    // MARK: - Audio Processing Utilities
    private func calculateZeroCrossingRate(_ audio: [Float]) -> Float {
        guard audio.count > 1 else { return 0.0 }
        
        var crossings = 0
        for i in 1..<audio.count {
            if (audio[i-1] >= 0 && audio[i] < 0) || (audio[i-1] < 0 && audio[i] >= 0) {
                crossings += 1
            }
        }
        
        return Float(crossings) / Float(audio.count - 1)
    }
    
    private func calculateSpectralCentroid(_ audio: [Float]) -> Float {
        let fft = performFFT(audio)
        let magnitudes = fft.magnitude
        
        var weightedSum: Float = 0.0
        var totalMagnitude: Float = 0.0
        
        for i in 0..<magnitudes.count {
            let frequency = Float(i) * Float(sampleRate) / Float(magnitudes.count * 2)
            weightedSum += frequency * magnitudes[i]
            totalMagnitude += magnitudes[i]
        }
        
        return totalMagnitude > 0 ? weightedSum / totalMagnitude : 0.0
    }
    
    private func calculateSpectralRolloff(_ audio: [Float]) -> Float {
        let fft = performFFT(audio)
        let magnitudes = fft.magnitude
        
        let totalEnergy = magnitudes.reduce(0, +)
        let threshold = totalEnergy * 0.85
        
        var cumulativeEnergy: Float = 0.0
        for i in 0..<magnitudes.count {
            cumulativeEnergy += magnitudes[i]
            if cumulativeEnergy >= threshold {
                return Float(i) * Float(sampleRate) / Float(magnitudes.count * 2)
            }
        }
        
        return Float(sampleRate) / 2.0
    }
    
    private func calculateSpectralBandwidth(_ audio: [Float]) -> Float {
        let centroid = calculateSpectralCentroid(audio)
        let fft = performFFT(audio)
        let magnitudes = fft.magnitude
        
        var weightedSum: Float = 0.0
        var totalMagnitude: Float = 0.0
        
        for i in 0..<magnitudes.count {
            let frequency = Float(i) * Float(sampleRate) / Float(magnitudes.count * 2)
            let diff = frequency - centroid
            weightedSum += diff * diff * magnitudes[i]
            totalMagnitude += magnitudes[i]
        }
        
        return totalMagnitude > 0 ? sqrt(weightedSum / totalMagnitude) : 0.0
    }
    
    private func calculateSpectralFlux(_ magnitudes: [Float]) -> Float {
        guard magnitudes.count > 1 else { return 0.0 }
        
        var flux: Float = 0.0
        for i in 1..<magnitudes.count {
            let diff = magnitudes[i] - magnitudes[i-1]
            flux += diff * diff
        }
        
        return sqrt(flux / Float(magnitudes.count - 1))
    }
    
    private func performFFT(_ audio: [Float]) -> (magnitude: [Float], phase: [Float]) {
        let n = audio.count
        let log2n = Int(log2(Float(n)))
        let fftSize = 1 << log2n
        
        var real = [Float](repeating: 0, count: fftSize)
        var imag = [Float](repeating: 0, count: fftSize)
        
        // Copy audio data to real part
        for i in 0..<min(n, fftSize) {
            real[i] = audio[i]
        }
        
        // Perform FFT using Accelerate framework
        var splitComplex = DSPSplitComplex(realp: &real, imagp: &imag)
        let fftSetup = vDSP_create_fftsetup(vDSP_Length(log2n), FFTRadix(kFFTRadix2))
        
        vDSP_fft_zrip(fftSetup!, &splitComplex, 1, vDSP_Length(log2n), FFTDirection(FFT_FORWARD))
        
        vDSP_destroy_fftsetup(fftSetup)
        
        // Calculate magnitude and phase
        var magnitudes = [Float](repeating: 0, count: fftSize/2)
        var phases = [Float](repeating: 0, count: fftSize/2)
        
        for i in 0..<fftSize/2 {
            let realVal = real[i]
            let imagVal = imag[i]
            magnitudes[i] = sqrt(realVal * realVal + imagVal * imagVal)
            phases[i] = atan2(imagVal, realVal)
        }
        
        return (magnitude: magnitudes, phase: phases)
    }
}

// MARK: - Data Structures
struct EchoDetectionResult {
    let isEcho: Bool
    let isRealSpeech: Bool
    let echoConfidence: Float
    let realSpeechConfidence: Float
    let overallConfidence: Float
    let mlPrediction: MLPrediction
    let correlation: Float
    let spectralSimilarity: Float
    let temporalAlignment: Float
}

struct MLPrediction {
    let echoProbability: Float
    let realSpeechProbability: Float
    let confidence: Float
}

struct AudioFeatures {
    var mfccCoefficients: [Float]?
    var melSpectrogram: [Float]?
    var statisticalFeatures = StatisticalFeatures()
    var spectralFeatures = SpectralFeatures()
}

struct StatisticalFeatures {
    var rmsEnergy: Float = 0.0
    var zeroCrossingRate: Float = 0.0
    var spectralCentroid: Float = 0.0
    var spectralRolloff: Float = 0.0
    var spectralBandwidth: Float = 0.0
}

struct SpectralFeatures {
    var magnitudeSpectrum: [Float] = []
    var phaseSpectrum: [Float] = []
    var spectralFlux: Float = 0.0
}

struct MLInputFeatures {
    var featureVector: [Float] = []
}

// MARK: - Feature Extractors
class MelSpectrogramExtractor {
    private let sampleRate: Int
    private let windowSize: Int
    private let hopSize: Int
    
    init(sampleRate: Int, windowSize: Int, hopSize: Int) {
        self.sampleRate = sampleRate
        self.windowSize = windowSize
        self.hopSize = hopSize
    }
    
    func extractMelSpectrogram(from audio: [Float]) -> [Float]? {
        // Simplified mel spectrogram extraction
        // In a real implementation, this would use more sophisticated algorithms
        
        let fft = performFFT(audio)
        let magnitudes = fft.magnitude
        
        // Apply mel filterbank (simplified)
        let melBands = applyMelFilterbank(magnitudes)
        
        return melBands
    }
    
    private func performFFT(_ audio: [Float]) -> (magnitude: [Float], phase: [Float]) {
        // Same FFT implementation as above
        let n = audio.count
        let log2n = Int(log2(Float(n)))
        let fftSize = 1 << log2n
        
        var real = [Float](repeating: 0, count: fftSize)
        var imag = [Float](repeating: 0, count: fftSize)
        
        for i in 0..<min(n, fftSize) {
            real[i] = audio[i]
        }
        
        var splitComplex = DSPSplitComplex(realp: &real, imagp: &imag)
        let fftSetup = vDSP_create_fftsetup(vDSP_Length(log2n), FFTRadix(kFFTRadix2))
        
        vDSP_fft_zrip(fftSetup!, &splitComplex, 1, vDSP_Length(log2n), FFTDirection(FFT_FORWARD))
        
        vDSP_destroy_fftsetup(fftSetup)
        
        var magnitudes = [Float](repeating: 0, count: fftSize/2)
        var phases = [Float](repeating: 0, count: fftSize/2)
        
        for i in 0..<fftSize/2 {
            let realVal = real[i]
            let imagVal = imag[i]
            magnitudes[i] = sqrt(realVal * realVal + imagVal * imagVal)
            phases[i] = atan2(imagVal, realVal)
        }
        
        return (magnitude: magnitudes, phase: phases)
    }
    
    private func applyMelFilterbank(_ magnitudes: [Float]) -> [Float] {
        // Simplified mel filterbank with 26 mel bands
        let numBands = 26
        var melBands = [Float](repeating: 0, count: numBands)
        
        // Simple averaging of frequency bins into mel bands
        let binsPerBand = magnitudes.count / numBands
        
        for i in 0..<numBands {
            let startBin = i * binsPerBand
            let endBin = min(startBin + binsPerBand, magnitudes.count)
            
            var sum: Float = 0.0
            for j in startBin..<endBin {
                sum += magnitudes[j]
            }
            
            melBands[i] = sum / Float(endBin - startBin)
        }
        
        return melBands
    }
}

class MFCCExtractor {
    private let sampleRate: Int
    private let windowSize: Int
    private let hopSize: Int
    
    init(sampleRate: Int, windowSize: Int, hopSize: Int) {
        self.sampleRate = sampleRate
        self.windowSize = windowSize
        self.hopSize = hopSize
    }
    
    func extractMFCC(from audio: [Float]) -> [Float]? {
        // Simplified MFCC extraction
        // In a real implementation, this would use proper MFCC calculation
        
        // For now, return a simplified feature vector
        var mfcc = [Float]()
        
        // Add basic statistical features as MFCC approximation
        let rms = sqrt(audio.map { $0 * $0 }.reduce(0, +) / Float(audio.count))
        mfcc.append(rms)
        
        let zeroCrossingRate = calculateZeroCrossingRate(audio)
        mfcc.append(zeroCrossingRate)
        
        let spectralCentroid = calculateSpectralCentroid(audio)
        mfcc.append(spectralCentroid)
        
        // Add more features to reach typical MFCC size (13 coefficients)
        for i in 3..<13 {
            mfcc.append(Float(i) * 0.1) // Placeholder values
        }
        
        return mfcc
    }
    
    private func calculateZeroCrossingRate(_ audio: [Float]) -> Float {
        guard audio.count > 1 else { return 0.0 }
        
        var crossings = 0
        for i in 1..<audio.count {
            if (audio[i-1] >= 0 && audio[i] < 0) || (audio[i-1] < 0 && audio[i] >= 0) {
                crossings += 1
            }
        }
        
        return Float(crossings) / Float(audio.count - 1)
    }
    
    private func calculateSpectralCentroid(_ audio: [Float]) -> Float {
        let n = audio.count
        let log2n = Int(log2(Float(n)))
        let fftSize = 1 << log2n
        
        var real = [Float](repeating: 0, count: fftSize)
        var imag = [Float](repeating: 0, count: fftSize)
        
        for i in 0..<min(n, fftSize) {
            real[i] = audio[i]
        }
        
        var splitComplex = DSPSplitComplex(realp: &real, imagp: &imag)
        let fftSetup = vDSP_create_fftsetup(vDSP_Length(log2n), FFTRadix(kFFTRadix2))
        
        vDSP_fft_zrip(fftSetup!, &splitComplex, 1, vDSP_Length(log2n), FFTDirection(FFT_FORWARD))
        
        vDSP_destroy_fftsetup(fftSetup)
        
        var magnitudes = [Float](repeating: 0, count: fftSize/2)
        
        for i in 0..<fftSize/2 {
            let realVal = real[i]
            let imagVal = imag[i]
            magnitudes[i] = sqrt(realVal * realVal + imagVal * imagVal)
        }
        
        var weightedSum: Float = 0.0
        var totalMagnitude: Float = 0.0
        
        for i in 0..<magnitudes.count {
            let frequency = Float(i) * Float(sampleRate) / Float(magnitudes.count * 2)
            weightedSum += frequency * magnitudes[i]
            totalMagnitude += magnitudes[i]
        }
        
        return totalMagnitude > 0 ? weightedSum / totalMagnitude : 0.0
    }
} 