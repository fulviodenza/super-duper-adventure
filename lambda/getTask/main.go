package main

import (
	"super-duper-adventure/cmd"

	"github.com/aws/aws-lambda-go/lambda"
)

func main() {
	lambda.Start(cmd.HandleGetRequest)
}
