# Upstream refactored code with Intel XPU support
def hello(device="cpu"):
    """Generic hello for any device."""
    print(f"Hello from {device}!")

def hello_cuda():
    print("Hello from CUDA!")

def hello_xpu():
    """Intel XPU accelerated hello."""
    print("Hello from Intel XPU!")

def hello_xpu_advanced():
    """Advanced XPU features."""
    print("Hello from XPU with SYCL backend!")
