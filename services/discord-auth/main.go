package main

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"os"
	"time"
)

type TokenRequest struct {
	Code string `json:"code"`
}

type TokenResponse struct {
	AccessToken string `json:"access_token"`
}

type DiscordTokenResponse struct {
	AccessToken  string `json:"access_token"`
	TokenType    string `json:"token_type"`
	ExpiresIn    int    `json:"expires_in"`
	RefreshToken string `json:"refresh_token"`
	Scope        string `json:"scope"`
}

type ErrorResponse struct {
	Error string `json:"error"`
}

func main() {
	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}

	http.HandleFunc("/api/discord/token", handleTokenExchange)
	http.HandleFunc("/health", handleHealth)

	log.Printf("Discord auth service starting on port %s", port)
	if err := http.ListenAndServe(":"+port, nil); err != nil {
		log.Fatal(err)
	}
}

func handleHealth(w http.ResponseWriter, r *http.Request) {
	w.WriteHeader(http.StatusOK)
	w.Write([]byte("OK"))
}

func handleTokenExchange(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	var req TokenRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		respondWithError(w, http.StatusBadRequest, "Invalid request body")
		return
	}

	if req.Code == "" {
		respondWithError(w, http.StatusBadRequest, "Code is required")
		return
	}

	clientID := os.Getenv("DISCORD_CLIENT_ID")
	clientSecret := os.Getenv("DISCORD_CLIENT_SECRET")
	redirectURI := os.Getenv("DISCORD_REDIRECT_URI")

	if clientID == "" || clientSecret == "" {
		log.Printf("Missing required environment variables")
		respondWithError(w, http.StatusInternalServerError, "Server configuration error")
		return
	}

	// Exchange code for token with Discord
	token, err := exchangeCodeForToken(req.Code, clientID, clientSecret, redirectURI)
	if err != nil {
		log.Printf("Failed to exchange code for token: %v", err)
		respondWithError(w, http.StatusBadRequest, "Failed to exchange code")
		return
	}

	respondWithJSON(w, http.StatusOK, TokenResponse{
		AccessToken: token.AccessToken,
	})
}

func exchangeCodeForToken(code, clientID, clientSecret, redirectURI string) (*DiscordTokenResponse, error) {
	url := "https://discord.com/api/oauth2/token"

	data := fmt.Sprintf("client_id=%s&client_secret=%s&grant_type=authorization_code&code=%s",
		clientID, clientSecret, code)
	if redirectURI != "" {
		data += fmt.Sprintf("&redirect_uri=%s", redirectURI)
	}

	client := &http.Client{
		Timeout: 10 * time.Second,
	}

	req, err := http.NewRequest("POST", url, bytes.NewBufferString(data))
	if err != nil {
		return nil, err
	}

	req.Header.Set("Content-Type", "application/x-www-form-urlencoded")

	resp, err := client.Do(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, err
	}

	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("discord returned status %d: %s", resp.StatusCode, string(body))
	}

	var tokenResp DiscordTokenResponse
	if err := json.Unmarshal(body, &tokenResp); err != nil {
		return nil, err
	}

	return &tokenResp, nil
}

func respondWithError(w http.ResponseWriter, code int, message string) {
	respondWithJSON(w, code, ErrorResponse{Error: message})
}

func respondWithJSON(w http.ResponseWriter, code int, payload interface{}) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(code)
	json.NewEncoder(w).Encode(payload)
}