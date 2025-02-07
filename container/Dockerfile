# Use the official Golang image to build the application
FROM golang:1.23 AS builder

# Set the working directory inside the container
WORKDIR /app

# Copy go modules and download dependencies
COPY go.mod go.sum ./
RUN --mount=type=cache,target=/go/pkg/mod go mod download

# Copy the source code
COPY . .

# Build the Go application
RUN --mount=type=cache,target=/root/.cache/go-build go build -o server .

# Use a minimal image for running the application
FROM gcr.io/distroless/base-debian12

# Set the working directory
WORKDIR /app

# Copy the built binary from the builder stage
COPY --from=builder /app/server /app/server

# Expose the port the application runs on
EXPOSE 8080

# Run the application
CMD ["/app/server"]

