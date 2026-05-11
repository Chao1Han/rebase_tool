"""Tests for hello entry points."""

from src.hello import hello, hello_cuda, hello_xpu, hello_xpu_advanced


def test_generic_hello_supports_device_override(capsys):
    """The generic hello entry point should keep device-specific output."""
    hello("xpu")
    assert capsys.readouterr().out == "Hello from xpu!\n"


def test_cuda_hello_entry_point(capsys):
    """The existing CUDA helper should remain available after rebase."""
    hello_cuda()
    assert capsys.readouterr().out == "Hello from CUDA!\n"


def test_private_xpu_hello_functions(capsys):
    """Intel-private XPU helpers should remain available after rebase."""
    hello_xpu()
    hello_xpu_advanced()
    assert capsys.readouterr().out.splitlines() == [
        "Hello from Intel XPU!",
        "Hello from XPU with SYCL backend!",
    ]
