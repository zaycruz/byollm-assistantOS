import runpy


def test_main_runs(capsys):
    runpy.run_path("main.py", run_name="__main__")
    captured = capsys.readouterr()
    assert "Hello from byollm-assistantos!" in captured.out



