# ---- Build stage ----
FROM python:3.14.3-alpine AS build-env

WORKDIR /app

# Alpine needs a compiler/headers for packages with native C extensions
RUN apk add --no-cache gcc musl-dev libffi-dev

COPY requirements.txt .
RUN pip install --user -r requirements.txt

# ---- Final stage ----
FROM python:3.14.3-alpine

WORKDIR /app

# Copy only the installed packages from the build stage, without the build toolchain
COPY --from=build-env /root/.local /root/.local
COPY app.py .

ENV PATH=/root/.local/bin:$PATH

EXPOSE 5000

CMD [ "python", "app.py" ]