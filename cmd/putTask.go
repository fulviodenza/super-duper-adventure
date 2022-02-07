package cmd

import (
	"fmt"
)

type MyEvent struct {
	Name string `json:"What is your name?"`
	Age  int    `json:"How old are you?"`
}

type MyResponse struct {
	Message string `json:"Answer:"`
}

func HandlePutRequest(event MyEvent) (MyResponse, error) {

	return MyResponse{Message: fmt.Sprintf("%s is %d years old!", event.Name, event.Age)}, nil

	// task := new(model.Task)

	// err := json.Unmarshal([]byte(request.Body), task)
	// if err != nil {
	// 	log.Println("Error unmarshaling body")
	// 	return events.APIGatewayProxyResponse{
	// 		StatusCode: http.StatusBadRequest,
	// 		Body:       err.Error(),
	// 	}, nil
	// }

	// err = database.Insert(task)
	// if err != nil {
	// 	log.Println("Error inserting task in database: ", err)
	// 	return events.APIGatewayProxyResponse{
	// 		StatusCode: http.StatusInternalServerError,
	// 		Body:       err.Error(),
	// 	}, nil
	// }

	// return events.APIGatewayProxyResponse{
	// 	StatusCode: http.StatusOK,
	// 	// Body:       "HA FUNZIONATOOO",
	// }, nil
}
