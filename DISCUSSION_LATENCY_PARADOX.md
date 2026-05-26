# Discussion: The Resolution-Latency Paradox in Hardware Encoding

## 1. Empirical Observation
During the hardware benchmarking phase of the system, a counterintuitive anomaly was observed within the latency data arrays. The empirical data indicated that the `1080p @ 60 FPS` configuration occasionally yielded a superior (lower) calculated inter-frame delay (e.g., 15.87 ms at micro-bursts of 63 FPS) when compared to the logically less demanding `720p @ 60 FPS` configuration (which hovered firmly around 16.13 ms at 62 FPS). From a fundamental bandwidth perspective, generating and transmitting a larger pixel matrix should theoretically incur higher processing penalties. This section dissects the underlying hardware and logic mechanics responsible for this anomaly.

## 2. Frame Pacing vs. True End-to-End Latency
To contextualize this discrepancy, it is vital to discern the difference between *pipeline frame pacing* and *end-to-end (photon-to-photon) latency*. 

The tracked metric (`Inter_Frame_Delay_ms`), derived mathematically via $1000 / \text{Actual\_FPS}$, quantifies the delivery cadence—specifically, the temporal gap between sequential packets arriving from the USB queue to the host decoder. It does not encapsulate the overarching timeline from the camera sensor's initial exposure to the host display's physical pixel illumination. The increased cadence at 1080p signifies that frames arrive back-to-back faster, stemming from USB burst transmissions padding the dispatch queue, rather than representing a holistic reduction in system latency.

## 3. Image Signal Processor (ISP) and Native Scaling Overhead
The primary structural driver of this pacing variance lies in the smartphone's internal rendering pipeline. Modern flagship mobile Systems-on-a-Chip (SoCs), such as the Qualcomm Snapdragon logic board utilized in the testing device, possess dedicated hardware video encoders (e.g., `c2.qti.hevc.encoder`) tailored for standard high-definition broadcast topologies, predominantly 1080p and 4K natively.

When the system requests a `720p` data stream, the camera pipeline is forced to interject an intermediary computational step:
1. Capture the high-resolution raw sensor crop.
2. Actively downscale the pixel matrix to 720p via the ISP.
3. Pass the downscaled buffer to the HEVC hardware encoder.

This real-time geometric scaling introduces micro-stutters and pacing variance to the encoding pipeline. Conversely, requesting a `1080p` stream often allows the SoC to bypass the downscaling overhead entirely. The hardware securely routes the native sensor buffer directly into the optimized encoder, resulting in a more sustained and fluid output framerate that mathematically translates into a tighter inter-frame delay logging.

## 4. Physical Transmission Reality
Despite the superior pipeline pacing of the 1080p stream, the unalterable constraints of physical transmission remain. The `1080p @ 60 FPS` configuration commands a target bitrate of ~24 Mbps, whereas the `720p` equivalent demands only ~16 Mbps. 

Consequently, the serialization of larger H.265 payloads, their traversal across the USB 2.0/3.0 bus layer, and the subsequent host-side deserialization require a marginally higher quantum of time. Therefore, while compiling at a smoother micro-cadence (yielding mathematically superior pacing), the true photon-to-photon latency of the 1080p feed remains inherently higher than its 720p counterpart due to payload size physics.