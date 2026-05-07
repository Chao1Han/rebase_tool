# Upstream refactored code with Intel XPU support
def hello(device="cpu"):
    """Generic hello for any device - v2.0."""
    print(f"[v2.0] Hello from {device}!")

def hello_cuda():
    """CUDA accelerated hello - refactored."""
    print("[CUDA] Hello from CUDA accelerator!")

def hello_xpu():
    """Intel XPU accelerated hello."""
    print("Hello from Intel XPU!")

def hello_xpu_advanced():
    """Advanced XPU features."""
    print("Hello from XPU with SYCL backend!")
