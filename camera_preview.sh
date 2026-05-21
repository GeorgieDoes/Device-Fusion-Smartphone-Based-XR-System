#!/bin/bash
python3 << 'PYTHON'
import subprocess
import pygame
import numpy as np
import cv2
import threading

pygame.init()
WIDTH, HEIGHT = 1280, 720
screen = pygame.display.set_mode((WIDTH, HEIGHT))
pygame.display.set_caption("RPi5 Camera Live - 60fps YUV420")

latest_frame = [None]
lock = threading.Lock()
running = True
frame_size = WIDTH * HEIGHT * 3 // 2  # YUV420

def capture_thread():
    global running
    proc = subprocess.Popen(
        ['rpicam-vid', '--camera', '0', '-t', '0', '--codec', 'yuv420',
         '--width', '1280', '--height', '720', '--framerate', '60', '-o', '-'],
        stdout=subprocess.PIPE,
        stderr=subprocess.DEVNULL,
        bufsize=262144
    )
    
    try:
        while running:
            frame_data = proc.stdout.read(frame_size)
            if len(frame_data) < frame_size:
                break
            
            # Convert YUV420 to BGR using OpenCV
            yuv_frame = np.frombuffer(frame_data, np.uint8).reshape((HEIGHT + HEIGHT//2, WIDTH))
            bgr = cv2.cvtColor(yuv_frame, cv2.COLOR_YUV2BGR_I420)
            
            frame = pygame.image.frombuffer(bgr.tobytes(), (WIDTH, HEIGHT), "BGR")
            
            with lock:
                latest_frame[0] = frame
    finally:
        proc.terminate()

t = threading.Thread(target=capture_thread, daemon=True)
t.start()

try:
    while running:
        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                running = False
        
        with lock:
            if latest_frame[0]:
                screen.blit(latest_frame[0], (0, 0))
        
        pygame.display.flip()

except KeyboardInterrupt:
    pass
finally:
    running = False
    pygame.quit()
PYTHON
