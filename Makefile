PROJECT={{ cookiecutter.project_name }}
VERSION=0.1.0
PYTHON_VERSION={{ cookiecutter.python_version }}
SOURCE_OBJECTS=src tests

setup:
	pip3 install --upgrade pip
	pip3 install -r requirements_dev.txt
	pip3 install -r requirements.txt

format.black:
	black ${SOURCE_OBJECTS}
format.isort:
	isort --atomic ${SOURCE_OBJECTS}
format: format.isort format.black

lints.format.check:
	black --check ${SOURCE_OBJECTS}
	isort --check-only ${SOURCE_OBJECTS}
lints.flake8:
	flake8 ${SOURCE_OBJECTS}
lints.mypy:
	mypy ${SOURCE_OBJECTS}
lints.pylint:
	pylint --rcfile setup.cfg ${SOURCE_OBJECTS} --fail-under=9
lints: lints.flake8 lints.pylint

test: setup
	coverage run -m pytest -s .

test.coverage: test
	coverage report -m --fail-under=90

