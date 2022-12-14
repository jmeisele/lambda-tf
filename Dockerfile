FROM public.ecr.aws/lambda/python:{{ cookiecutter.python_version }}

# Copy function code
COPY src/lambda_func.py ${LAMBDA_TASK_ROOT}

# Install the function's dependencies using file requirements.txt
# from your project folder.
COPY requirements.txt  .
RUN  pip3 install -r requirements.txt --target "${LAMBDA_TASK_ROOT}"

# Set the CMD to your handler (could also be done as a parameter override outside of the Dockerfile)
CMD ["lambda_func.lambda_handler"]