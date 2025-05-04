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
YELLOW='\033[0;33m'

# Funkcja do sprawdzania stanu baz danych
check_database_state() {
    echo -e "\n${YELLOW}===== SPRAWDZANIE STANU BAZ DANYCH =====${NC}"
    
    # Sprawdzenie PostgreSQL
    echo -e "\n${YELLOW}Sprawdzanie PostgreSQL:${NC}"
    echo -e "Użytkownicy:"
    docker exec -it postgres psql -U postgres_user -d eventsdb -c "SELECT id, name, email, role FROM users LIMIT 5;"
    
    echo -e "\nWydarzenia:"
    docker exec -it postgres psql -U postgres_user -d eventsdb -c "SELECT id, title, available_seats, total_seats FROM events LIMIT 5;"
    
    echo -e "\nBilety:"
    docker exec -it postgres psql -U postgres_user -d eventsdb -c "SELECT id, ticket_number, status, event_id, user_id FROM tickets LIMIT 5;"
    
    echo -e "\nPłatności:"
    docker exec -it postgres psql -U postgres_user -d eventsdb -c "SELECT id, amount, payment_method, status FROM payments LIMIT 5;"
    
    # Sprawdzenie MongoDB
    echo -e "\n${YELLOW}Sprawdzanie MongoDB:${NC}"
    echo -e "Komentarze:"
    docker exec -it mongodb mongo eventsdb --quiet --eval 'db.comments.find().limit(5).pretty()'
    
    echo -e "\nRecenzje:"
    docker exec -it mongodb mongo eventsdb --quiet --eval 'db.reviews.find().limit(5).pretty()'
    
    # Sprawdzenie Redis
    echo -e "\n${YELLOW}Sprawdzanie Redis:${NC}"
    echo -e "Cache wydarzenia:"
    docker exec -it redis redis-cli KEYS "event:*"
    
    echo -e "\nRezerwacje:"
    docker exec -it redis redis-cli KEYS "reservation:*"
    
    echo -e "\nDostępne miejsca:"
    docker exec -it redis redis-cli KEYS "event:*:seats"
    
    # Pokaż przykładową rezerwację jeśli istnieje
    RESERVATION_KEY=$(docker exec -it redis redis-cli KEYS "reservation:*" | head -n 1)
    if [ ! -z "$RESERVATION_KEY" ]; then
        echo -e "\nPrzykładowa rezerwacja ($RESERVATION_KEY):"
        docker exec -it redis redis-cli GET "$RESERVATION_KEY"
    fi
}

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

# Sprawdzanie stanu baz po rejestracji
check_database_state

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

# Sprawdzanie stanu baz po utworzeniu wydarzenia
check_database_state

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

# Sprawdzanie stanu MongoDB po dodaniu komentarza
echo -e "\n${YELLOW}Sprawdzanie MongoDB po dodaniu komentarza:${NC}"
docker exec -it mongodb mongo eventsdb --quiet --eval "db.comments.find({eventId: \"$EVENT_ID\"}).pretty()"

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

# Sprawdzanie stanu Redis po rezerwacji
echo -e "\n${YELLOW}Sprawdzanie Redis po rezerwacji:${NC}"
docker exec -it redis redis-cli GET "reservation:$RESERVATION_ID"
docker exec -it redis redis-cli GET "event:$EVENT_ID:seats"
docker exec -it redis redis-cli GET "event:$EVENT_ID:temp_seats"

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

# Sprawdzanie stanu baz po zakupie biletu
check_database_state

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

# Sprawdzanie stanu MongoDB po dodaniu recenzji
echo -e "\n${YELLOW}Sprawdzanie MongoDB po dodaniu recenzji:${NC}"
docker exec -it mongodb mongo eventsdb --quiet --eval "db.reviews.find({eventId: \"$EVENT_ID\"}).pretty()"

# 12. Anulowanie biletu
echo -e "\n${BLUE}12. Anulowanie biletu${NC}"
curl -s -X PUT $BASE_URL/tickets/$TICKET_ID/cancel \
  -H "Authorization: Bearer $TOKEN" | jq

# Sprawdzanie stanu baz po anulowaniu biletu
check_database_state

echo -e "\n${GREEN}Testy zostały zakończone!${NC}"

# Podsumowanie
echo -e "\n${GREEN}===== PODSUMOWANIE TESTÓW =====${NC}"
echo -e "1. Zarejestrowano użytkownika organizatora"
echo -e "2. Zarejestrowano zwykłego użytkownika"
echo -e "3. Utworzono wydarzenie: Koncert Muzyki Klasycznej"
echo -e "4. Pobrano informacje o wydarzeniu"
echo -e "5. Dodano komentarz do wydarzenia"
echo -e "6. Pobrano komentarze wydarzenia"
echo -e "7. Dokonano rezerwacji 2 biletów"
echo -e "8. Zakupiono bilety"
echo -e "9. Pobrano bilety użytkownika"
echo -e "10. Dodano recenzję wydarzenia"
echo -e "11. Pobrano recenzje wydarzenia"
echo -e "12. Anulowano bilet"

# Sprawdzenie końcowego stanu baz
echo -e "\n${YELLOW}Końcowy stan baz danych po wszystkich operacjach:${NC}"

# Sprawdzenie PostgreSQL - bilety
echo -e "\n${YELLOW}PostgreSQL - Stan biletów:${NC}"
docker exec -it postgres psql -U postgres_user -d eventsdb -c "SELECT id, ticket_number, status, event_id, user_id FROM tickets;"

# Sprawdzenie PostgreSQL - dostępne miejsca
echo -e "\n${YELLOW}PostgreSQL - Dostępne miejsca w wydarzeniu:${NC}"
docker exec -it postgres psql -U postgres_user -d eventsdb -c "SELECT id, title, available_seats, total_seats FROM events WHERE id='$EVENT_ID';"

# Sprawdzenie Redis - cache dostępnych miejsc
echo -e "\n${YELLOW}Redis - Cache dostępnych miejsc:${NC}"
docker exec -it redis redis-cli GET "event:$EVENT_ID:seats"

# Sprawdzenie MongoDB - wszystkie komentarze i recenzje
echo -e "\n${YELLOW}MongoDB - Wszystkie komentarze i recenzje:${NC}"
docker exec -it mongodb mongo eventsdb --quiet --eval 'db.comments.count() + " komentarzy, " + db.reviews.count() + " recenzji"'