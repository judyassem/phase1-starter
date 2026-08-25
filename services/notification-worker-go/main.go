package main

import (
	"encoding/json"
	"log"
	"os"

	amqp "github.com/rabbitmq/amqp091-go"
)

type BookingEvent struct {
	BookingID string `json:"bookingId"`
	UserID    string `json:"userId"`
	EventID   int    `json:"eventId"`
}

func rabbitMQURL() string {
	url := os.Getenv("RABBITMQ_URL")

	if url == "" {
		url = "amqp://guest:guest@localhost:5672/"
	}

	return url
}

func queueName() string {
	queue := os.Getenv("RABBITMQ_QUEUE")

	if queue == "" {
		queue = "bookings"
	}

	return queue
}

// healthcheck connects to RabbitMQ and exits.
// Exit code 0 = healthy
// Exit code 1 = unhealthy
func healthcheck() {
	url := rabbitMQURL()

	conn, err := amqp.Dial(url)
	if err != nil {
		log.Printf("healthcheck failed: %v", err)
		os.Exit(1)
	}

	defer conn.Close()

	log.Println("healthcheck: RabbitMQ connection OK")
	os.Exit(0)
}

func main() {

	// If Podman runs:
	// /app/notification-worker --healthcheck
	// perform the healthcheck instead of starting the worker.
	if len(os.Args) > 1 && os.Args[1] == "--healthcheck" {
		healthcheck()
	}

	url := rabbitMQURL()
	queue := queueName()

	conn, err := amqp.Dial(url)
	if err != nil {
		log.Fatalf("failed to connect to rabbitmq: %v", err)
	}
	defer conn.Close()

	ch, err := conn.Channel()
	if err != nil {
		log.Fatalf("failed to open channel: %v", err)
	}
	defer ch.Close()

	_, err = ch.QueueDeclare(
		queue,
		true,
		false,
		false,
		false,
		nil,
	)

	if err != nil {
		log.Fatalf("failed to declare queue: %v", err)
	}

	msgs, err := ch.Consume(
		queue,
		"",
		true,
		false,
		false,
		false,
		nil,
	)

	if err != nil {
		log.Fatalf("failed to register consumer: %v", err)
	}

	log.Printf("notification-worker listening on queue %q", queue)

	for msg := range msgs {
		var event BookingEvent

		if err := json.Unmarshal(msg.Body, &event); err != nil {
			log.Printf("skipping malformed message: %v", err)
			continue
		}

		log.Printf(
			"notification: booking %s confirmed for user %s (event %d)",
			event.BookingID,
			event.UserID,
			event.EventID,
		)
	}
}