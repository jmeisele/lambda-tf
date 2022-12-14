FROM public.ecr.aws/lambda/python:3.9

# Copy function code
COPY lambda_tf/lambda_func.py ${LAMBDA_TASK_ROOT}

# Install the function's dependencies using file requirements.txt
# from your project folder.
COPY pyproject.toml  .
RUN pip3 install poetry==1.3.1
RUN poetry export --format requirements.txt --output requirements.txt
RUN pip3 install -r requirements.txt --target "${LAMBDA_TASK_ROOT}"

# Set the CMD to your handler (could also be done as a parameter override outside of the Dockerfile)
CMD ["lambda_func.lambda_handler"]