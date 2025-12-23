import runpy


def test_main_runs(capsys):
    runpy.run_path("main.py", run_name="__main__")
    captured = capsys.readouterr()
    assert "Hello from byollm-assistantos!" in captured.out


def test_main_runs_twice(capsys):
    # Regression guard: running the entrypoint multiple times shouldn't hang or crash.
    runpy.run_path("main.py", run_name="__main__")
    runpy.run_path("main.py", run_name="__main__")
    captured = capsys.readouterr()
    assert captured.out.count("Hello from byollm-assistantos!") == 2



