#!/usr/bin/env python3
"""
Camera RTSP delay manager
@update: 2025-12-30
@version: v1.1.0
@author: wy
sudo apt update
sudo apt install -y \
     python3-gi \
     python3-gst-1.0 \
     gstreamer1.0-tools \
     gstreamer1.0-plugins-base \
     gstreamer1.0-plugins-good \
     gstreamer1.0-plugins-bad \
     gstreamer1.0-plugins-ugly \
     gstreamer1.0-libav \
     gstreamer1.0-rtsp \
     gstreamer1.0-alsa
- 严格 5s 延迟（min-threshold-time）
- 多 camera 独立 pipeline
- 单路 ERROR/EOS 自动重连
- 防 pipeline 叠加 bus 泄露

"""

import gi
import sys
import signal

gi.require_version('Gst', '1.0')
gi.require_version('GLib', '2.0')

from gi.repository import Gst, GLib

Gst.init(sys.argv)

# =========================
# Camera 配置
# =========================
CAMERAS = [
   {
    "name": "camera1",
    "source": "rtsp://127.0.0.1:8554/camera1",
    "sink":   "rtsp://127.0.0.1:8554/camera1-5s",
   },
   {
    "name": "camera2",
    "source": "rtsp://127.0.0.1:8554/camera2",
    "sink":   "rtsp://127.0.0.1:8554/camera2-5s",
   },
    {
     "name": "camera3",
     "source": "rtsp://127.0.0.1:8554/camera3",
     "sink":   "rtsp://127.0.0.1:8554/camera3-5s",
    }
]
# =========================
# pipeline 参数
# =========================
PIPELINE_CMD = (
    'rtspsrc location="{source}" protocols=tcp latency=0 ! '
    'rtph264depay ! h264parse ! '
    'queue max-size-buffers=0 max-size-bytes=0 '
    'min-threshold-time=5000000000 leaky=0 ! '
    'rtspclientsink location="{sink}" protocols=tcp'
)

RETRY_INTERVAL = 60    # 恢复时间60秒

# =========================
# 单路 Camera Pipeline
# =========================
class CameraPipeline:
    def __init__(self, cam):
        self.name = cam["name"]
        self.source = cam["source"]
        self.sink = cam["sink"]
        self.pipeline = None
        self.bus = None
        self.bus_handler_id = None
        self.retry_timer_id = None
        self.running = False

    def build_pipeline(self):
        desc = PIPELINE_CMD.format(source=self.source,sink=self.sink)
        self.pipeline = Gst.parse_launch(desc)
        self.bus = self.pipeline.get_bus()
        self.bus.add_signal_watch()
        self.bus_handler_id = self.bus.connect("message", self.bus_message)


    def destroy_pipeline(self):
        if not self.pipeline:
            return
        print(f"[{self.name}] destroying pipeline")
        if self.bus and self.bus_handler_id:
            self.bus.disconnect(self.bus_handler_id)
            self.bus_handler_id = None
            self.bus.remove_signal_watch()

        self.pipeline.set_state(Gst.State.NULL)
        self.pipeline.get_state(Gst.CLOCK_TIME_NONE)
        self.pipeline = None
        self.bus = None

    def start(self):
        if self.pipeline:
            return
        print(f"[{self.name}] starting pipeline")
        self.build_pipeline()
        ret = self.pipeline.set_state(Gst.State.PLAYING)

        if ret == Gst.StateChangeReturn.FAILURE:
            print(f"[{self.name}] playing failed immediately")
            self.running = False
            self.schedule_retry()
        else:
            self.running = True

    def stop(self):
        print(f"[{self.name}] stopping")
        self.running = False
        self.cancel_retry()
        self.destroy_pipeline()

    def schedule_retry(self):
        if self.retry_timer_id is not None:
            return
        print(f"[{self.name}] retry loop, interval: {RETRY_INTERVAL}s")
        self.retry_timer_id = GLib.timeout_add_seconds(RETRY_INTERVAL,self.retry_tick)

    def cancel_retry(self):
        if self.retry_timer_id:
            GLib.source_remove(self.retry_timer_id)
            self.retry_timer_id = None

    def retry_tick(self):
        print(f"[{self.name}] retry tick")
        self.destroy_pipeline()
        self.start()

        if self.running:
            print(f"[{self.name}] recovered")
            self.retry_timer_id = None
            return False
        return True

    def bus_message(self, bus, msg):
        t = msg.type
        if t == Gst.MessageType.ERROR:
            err, _ = msg.parse_error()
            print(f"[{self.name}] ERROR: {err}")
            self.running = False
            self.destroy_pipeline()
            self.schedule_retry()
        elif t == Gst.MessageType.EOS:
            print(f"[{self.name}] EOS")
            self.running = False
            self.destroy_pipeline()
            self.schedule_retry()
        return True

# =========================
# Manager（统一管理）
# =========================
class RTSPManager:
    def __init__(self, cameras):
        self.loop = GLib.MainLoop()
        self.cameras = [CameraPipeline(c) for c in cameras]

    def start(self):
        for cam in self.cameras:
            cam.start()
        self.loop.run()

    def stop(self):
        for cam in self.cameras:
            cam.stop()
        self.loop.quit()

# =========================
# main主程序
# =========================
if __name__ == "__main__":
    manager = RTSPManager(CAMERAS)

    signal.signal(signal.SIGINT,  lambda s, f: manager.stop())
    signal.signal(signal.SIGTERM, lambda s, f: manager.stop())

    manager.start()