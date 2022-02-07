package cmd

import (
	"context"
	"encoding/json"
	"log"
	"net/http"
	"super-duper-adventure/database"

	"github.com/aws/aws-lambda-go/events"
)

// handleRequest takes all tasks from the
// database and returns them to the client
func HandleGetRequest(ctx context.Context, request events.APIGatewayProxyRequest) (events.APIGatewayProxyResponse, error) {

	tasks := database.Get()

	j, err := json.Marshal(tasks)
	if err != nil {
		log.Println("Error marshaling")
		return events.APIGatewayProxyResponse{
			StatusCode: http.StatusInternalServerError,
			Body:       "Error marshaling",
		}, nil
	}

	return events.APIGatewayProxyResponse{
		StatusCode: http.StatusOK,
		Body:       string(j),
	}, nil
}
