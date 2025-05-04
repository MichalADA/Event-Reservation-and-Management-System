#!/bin/bash

BASE_URL="http://localhost:3000/api"
TOKEN=""
USER_ID=""
EVENT_ID=""
RESERVATION_ID=""
TICKET_ID=""

# Kolory dla lepszej czytelności
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color
BLUE='\033[0;34m'

echo -e "${BLUE}===== TESTOWANIE SYSTEMU REZERWACJI WYDARZEŃ =====${NC}\n"

# 1. Rejestracja użytkownika organizatora
echo -e "${BLUE}1. Rejestracja użytkownika organizatora${NC}"
ORGANIZER_RESPONSE=$(curl -s -X POST $BASE_URL/auth/register \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Jan Kowalski",
    "email": "organizer@example.com",
    "password": "password123",
    "role": "organizer",
    "phone": "123456789"
  }')

echo $ORGANIZER_RESPONSE | jq
ORGANIZER_TOKEN=$(echo $ORGANIZER_RESPONSE | jq -r '.token')

# 2. Rejestracja zwykłego użytkownika
echo -e "\n${BLUE}2. Rejestracja zwykłego użytkownika${NC}"
USER_RESPONSE=$(curl -s -X POST $BASE_URL/auth/register \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Anna Nowak",
    "email": "user@example.com",
    "password": "password123",
    "role": "customer",
    "phone": "987654321"
  }')

echo $USER_RESPONSE | jq
TOKEN=$(echo $USER_RESPONSE | jq -r '.token')
USER_ID=$(echo $USER_RESPONSE | jq -r '.user.id')

# 3. Tworzenie wydarzenia
echo -e "\n${BLUE}3. Tworzenie wydarzenia${NC}"
EVENT_RESPONSE=$(curl -s -X POST $BASE_URL/events \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $ORGANIZER_TOKEN" \
  -d '{
    "title": "Koncert Muzyki Klasycznej",
    "description": "Wspaniały koncert muzyki klasycznej w wykonaniu orkiestry symfonicznej",
    "startDate": "2025-06-15T18:00:00.000Z",
    "endDate": "2025-06-15T21:00:00.000Z",
    "location": "Filharmonia Narodowa, Warszawa",
    "totalSeats": 100,
    "price": 150.00,
    "category": "Muzyka",
    "isPublished": true
  }')

echo $EVENT_RESPONSE | jq
EVENT_ID=$(echo $EVENT_RESPONSE | jq -r '.id')

# 4. Pobieranie informacji o wydarzeniu
echo -e "\n${BLUE}4. Pobieranie informacji o wydarzeniu${NC}"
curl -s -X GET $BASE_URL/events/$EVENT_ID | jq

# 5. Dodawanie komentarza do wydarzenia
echo -e "\n${BLUE}5. Dodawanie komentarza do wydarzenia${NC}"
curl -s -X POST $BASE_URL/events/$EVENT_ID/comments \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{
    "userName": "Anna Nowak",
    "text": "Nie mogę się doczekać tego koncertu!"
  }' | jq

# 6. Pobieranie komentarzy wydarzenia
echo -e "\n${BLUE}6. Pobieranie komentarzy wydarzenia${NC}"
curl -s -X GET $BASE_URL/events/$EVENT_ID/comments | jq

# 7. Rezerwacja biletu
echo -e "\n${BLUE}7. Rezerwacja biletu${NC}"
RESERVATION_RESPONSE=$(curl -s -X POST $BASE_URL/tickets/reserve \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d "{
    \"eventId\": \"$EVENT_ID\",
    \"quantity\": 2
  }")

echo $RESERVATION_RESPONSE | jq
RESERVATION_ID=$(echo $RESERVATION_RESPONSE | jq -r '.reservationId')

# 8. Zakup biletu
echo -e "\n${BLUE}8. Zakup biletu${NC}"
PURCHASE_RESPONSE=$(curl -s -X POST $BASE_URL/tickets/purchase \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d "{
    \"reservationId\": \"$RESERVATION_ID\",
    \"paymentInfo\": {
      \"method\": \"credit_card\",
      \"transactionId\": \"test-transaction-123\"
    }
  }")

echo $PURCHASE_RESPONSE | jq
TICKET_ID=$(echo $PURCHASE_RESPONSE | jq -r '.tickets[0].id')

# 9. Pobranie biletów użytkownika
echo -e "\n${BLUE}9. Pobranie biletów użytkownika${NC}"
curl -s -X GET $BASE_URL/tickets/my-tickets \
  -H "Authorization: Bearer $TOKEN" | jq

# 10. Dodawanie recenzji
echo -e "\n${BLUE}10. Dodawanie recenzji${NC}"
curl -s -X POST $BASE_URL/events/$EVENT_ID/reviews \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{
    "userName": "Anna Nowak",
    "rating": 5,
    "title": "Wspaniały koncert!",
    "text": "Jeden z najlepszych koncertów na jakich byłam. Polecam!"
  }' | jq

# 11. Pobieranie recenzji wydarzenia
echo -e "\n${BLUE}11. Pobieranie recenzji wydarzenia${NC}"
curl -s -X GET $BASE_URL/events/$EVENT_ID/reviews | jq

# 12. Anulowanie biletu
echo -e "\n${BLUE}12. Anulowanie biletu${NC}"
curl -s -X PUT $BASE_URL/tickets/$TICKET_ID/cancel \
  -H "Authorization: Bearer $TOKEN" | jq

echo -e "\n${GREEN}Testy zostały zakończone!${NC}"
