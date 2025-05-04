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
    
    # Sprawdzenie PostgreSQL - najpierw sprawdzamy czy tabele istnieją
    echo -e "\n${YELLOW}Sprawdzanie PostgreSQL:${NC}"
    echo -e "Lista tabel:"
    docker exec -it postgres psql -U postgres_user -d eventsdb -c "\dt"
    
    # Sprawdzamy czy tabela użytkowników istnieje i wyświetlamy dane
    echo -e "\nUżytkownicy:"
    USERS_EXIST=$(docker exec -it postgres psql -U postgres_user -d eventsdb -c "SELECT EXISTS (SELECT FROM information_schema.tables WHERE table_name = 'users');" -t | tr -d ' ')
    if [ "$USERS_EXIST" = "t" ]; then
        docker exec -it postgres psql -U postgres_user -d eventsdb -c "SELECT id, name, email, role FROM users LIMIT 5;"
    else
        echo -e "${RED}Tabela 'users' nie istnieje${NC}"
    fi
    
    # Sprawdzamy czy tabela wydarzeń istnieje i wyświetlamy dane
    echo -e "\nWydarzenia:"
    EVENTS_EXIST=$(docker exec -it postgres psql -U postgres_user -d eventsdb -c "SELECT EXISTS (SELECT FROM information_schema.tables WHERE table_name = 'events');" -t | tr -d ' ')
    if [ "$EVENTS_EXIST" = "t" ]; then
        docker exec -it postgres psql -U postgres_user -d eventsdb -c "SELECT id, title, total_seats, available_seats FROM events LIMIT 5;"
    else
        echo -e "${RED}Tabela 'events' nie istnieje${NC}"
    fi
    
    # Sprawdzamy czy tabela biletów istnieje i wyświetlamy dane
    echo -e "\nBilety:"
    TICKETS_EXIST=$(docker exec -it postgres psql -U postgres_user -d eventsdb -c "SELECT EXISTS (SELECT FROM information_schema.tables WHERE table_name = 'tickets');" -t | tr -d ' ')
    if [ "$TICKETS_EXIST" = "t" ]; then
        docker exec -it postgres psql -U postgres_user -d eventsdb -c "SELECT id, ticket_number, status, event_id, user_id FROM tickets LIMIT 5;"
    else
        echo -e "${RED}Tabela 'tickets' nie istnieje${NC}"
    fi
    
    # Sprawdzamy czy tabela płatności istnieje i wyświetlamy dane
    echo -e "\nPłatności:"
    PAYMENTS_EXIST=$(docker exec -it postgres psql -U postgres_user -d eventsdb -c "SELECT EXISTS (SELECT FROM information_schema.tables WHERE table_name = 'payments');" -t | tr -d ' ')
    if [ "$PAYMENTS_EXIST" = "t" ]; then
        docker exec -it postgres psql -U postgres_user -d eventsdb -c "SELECT id, amount, payment_method, status FROM payments LIMIT 5;"
    else
        echo -e "${RED}Tabela 'payments' nie istnieje${NC}"
    fi
    
    # Sprawdzenie MongoDB - używamy mongosh zamiast mongo
    echo -e "\n${YELLOW}Sprawdzanie MongoDB:${NC}"
    echo -e "Lista kolekcji:"
    MONGO_CMD="mongosh"
    MONGO_EXIST=$(docker exec -it mongodb which mongosh || docker exec -it mongodb which mongo || echo "not_found")
    
    if [ "$MONGO_EXIST" = "not_found" ]; then
        echo -e "${RED}Nie można znaleźć polecenia mongosh ani mongo w kontenerze${NC}"
    else
        if [[ "$MONGO_EXIST" == */mongo ]]; then
            MONGO_CMD="mongo"
        fi
        
        docker exec -it mongodb $MONGO_CMD eventsdb --quiet --eval 'db.getCollectionNames()'
        
        echo -e "\nKomentarze:"
        docker exec -it mongodb $MONGO_CMD eventsdb --quiet --eval 'db.comments.find().limit(5).toArray()'
        
        echo -e "\nRecenzje:"
        docker exec -it mongodb $MONGO_CMD eventsdb --quiet --eval 'db.reviews.find().limit(5).toArray()'
    fi
    
    # Sprawdzenie Redis
    echo -e "\n${YELLOW}Sprawdzanie Redis:${NC}"
    echo -e "Wszystkie klucze:"
    docker exec -it redis redis-cli KEYS "*"
    
    echo -e "\nCache wydarzenia:"
    docker exec -it redis redis-cli KEYS "event:*"
    
    echo -e "\nRezerwacje:"
    docker exec -it redis redis-cli KEYS "reservation:*"
    
    echo -e "\nDostępne miejsca:"
    docker exec -it redis redis-cli KEYS "event:*:seats"
}

echo -e "${BLUE}===== TESTOWANIE SYSTEMU REZERWACJI WYDARZEŃ =====${NC}\n"

# Sprawdzamy czy serwer API działa
echo -e "${BLUE}Sprawdzanie połączenia z serwerem API...${NC}"
if curl -s -f -o /dev/null $BASE_URL/health-check; then
    echo -e "${GREEN}Serwer API działa poprawnie${NC}"
else
    echo -e "${RED}Nie można połączyć się z serwerem API pod adresem $BASE_URL${NC}"
    echo -e "Upewnij się, że serwer jest uruchomiony i dostępny."
    exit 1
fi

# Sprawdzamy stan baz danych przed testem
echo -e "\n${BLUE}Sprawdzanie stanu baz danych przed rozpoczęciem testów...${NC}"
check_database_state

echo -e "\n${BLUE}Czy chcesz kontynuować testy? (t/n)${NC}"
read -r choice
if [ "$choice" != "t" ]; then
    echo -e "${YELLOW}Testy zostały przerwane przez użytkownika${NC}"
    exit 0
fi

# 1. Rejestracja użytkownika organizatora
echo -e "\n${BLUE}1. Rejestracja użytkownika organizatora${NC}"
ORGANIZER_RESPONSE=$(curl -s -X POST $BASE_URL/auth/register \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Jan Kowalski",
    "email": "organizer@example.com",
    "password": "password123",
    "role": "organizer",
    "phone": "123456789"
  }')

echo $ORGANIZER_RESPONSE
# Sprawdzamy, czy odpowiedź jest w formacie JSON i zawiera token
if [[ $ORGANIZER_RESPONSE == *"token"* ]]; then
    ORGANIZER_TOKEN=$(echo $ORGANIZER_RESPONSE | jq -r '.token 2>/dev/null')
    if [ -z "$ORGANIZER_TOKEN" ] || [ "$ORGANIZER_TOKEN" == "null" ]; then
        echo -e "${RED}Nie można uzyskać tokenu organizatora.${NC}"
        ORGANIZER_TOKEN=""
    else
        echo -e "${GREEN}Pomyślnie zarejestrowano organizatora.${NC}"
    fi
else
    echo -e "${RED}Rejestracja organizatora nie powiodła się. Odpowiedź serwera:${NC}"
    echo $ORGANIZER_RESPONSE
    ORGANIZER_TOKEN=""
fi

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

echo $USER_RESPONSE
# Sprawdzamy, czy odpowiedź jest w formacie JSON i zawiera token
if [[ $USER_RESPONSE == *"token"* ]]; then
    TOKEN=$(echo $USER_RESPONSE | jq -r '.token 2>/dev/null')
    USER_ID=$(echo $USER_RESPONSE | jq -r '.user.id 2>/dev/null')
    if [ -z "$TOKEN" ] || [ "$TOKEN" == "null" ]; then
        echo -e "${RED}Nie można uzyskać tokenu użytkownika.${NC}"
        TOKEN=""
        USER_ID=""
    else
        echo -e "${GREEN}Pomyślnie zarejestrowano użytkownika.${NC}"
    fi
else
    echo -e "${RED}Rejestracja użytkownika nie powiodła się. Odpowiedź serwera:${NC}"
    echo $USER_RESPONSE
    TOKEN=""
    USER_ID=""
fi

# Sprawdzanie stanu baz po rejestracji
if [ ! -z "$TOKEN" ] && [ ! -z "$ORGANIZER_TOKEN" ]; then
    echo -e "\n${BLUE}Sprawdzanie stanu baz danych po rejestracji użytkowników...${NC}"
    check_database_state
else
    echo -e "${RED}Nie można kontynuować testów bez tokenów uwierzytelniania.${NC}"
    exit 1
fi

# 3. Tworzenie wydarzenia
echo -e "\n${BLUE}3. Tworzenie wydarzenia${NC}"
if [ -z "$ORGANIZER_TOKEN" ]; then
    echo -e "${RED}Brak tokenu organizatora. Nie można utworzyć wydarzenia.${NC}"
else
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

    echo $EVENT_RESPONSE
    # Sprawdzamy, czy odpowiedź zawiera ID wydarzenia
    if [[ $EVENT_RESPONSE == *"id"* ]]; then
        EVENT_ID=$(echo $EVENT_RESPONSE | jq -r '.id 2>/dev/null')
        if [ -z "$EVENT_ID" ] || [ "$EVENT_ID" == "null" ]; then
            echo -e "${RED}Nie można uzyskać ID wydarzenia.${NC}"
            EVENT_ID=""
        else
            echo -e "${GREEN}Pomyślnie utworzono wydarzenie.${NC}"
        fi
    else
        echo -e "${RED}Tworzenie wydarzenia nie powiodło się. Odpowiedź serwera:${NC}"
        echo $EVENT_RESPONSE
        EVENT_ID=""
    fi
fi

# Kontynuuj tylko jeśli mamy ID wydarzenia
if [ -z "$EVENT_ID" ]; then
    echo -e "${RED}Brak ID wydarzenia. Nie można kontynuować testów.${NC}"
    exit 1
fi

# 4. Pobieranie informacji o wydarzeniu
echo -e "\n${BLUE}4. Pobieranie informacji o wydarzeniu${NC}"
EVENT_INFO=$(curl -s -X GET $BASE_URL/events/$EVENT_ID)
echo $EVENT_INFO

# 5. Dodawanie komentarza do wydarzenia
echo -e "\n${BLUE}5. Dodawanie komentarza do wydarzenia${NC}"
if [ -z "$TOKEN" ]; then
    echo -e "${RED}Brak tokenu użytkownika. Nie można dodać komentarza.${NC}"
else
    COMMENT_RESPONSE=$(curl -s -X POST $BASE_URL/events/$EVENT_ID/comments \
      -H "Content-Type: application/json" \
      -H "Authorization: Bearer $TOKEN" \
      -d '{
        "userName": "Anna Nowak",
        "text": "Nie mogę się doczekać tego koncertu!"
      }')
    echo $COMMENT_RESPONSE
    if [[ $COMMENT_RESPONSE == *"_id"* ]]; then
        echo -e "${GREEN}Pomyślnie dodano komentarz.${NC}"
    else
        echo -e "${RED}Dodawanie komentarza nie powiodło się. Odpowiedź serwera:${NC}"
        echo $COMMENT_RESPONSE
    fi
fi

# 6. Pobieranie komentarzy wydarzenia
echo -e "\n${BLUE}6. Pobieranie komentarzy wydarzenia${NC}"
COMMENTS=$(curl -s -X GET $BASE_URL/events/$EVENT_ID/comments)
echo $COMMENTS

# Sprawdzanie stanu MongoDB po dodaniu komentarza
echo -e "\n${BLUE}Sprawdzanie stanu baz danych po dodaniu komentarza...${NC}"
check_database_state

# 7. Rezerwacja biletu
echo -e "\n${BLUE}7. Rezerwacja biletu${NC}"
if [ -z "$TOKEN" ]; then
    echo -e "${RED}Brak tokenu użytkownika. Nie można dokonać rezerwacji.${NC}"
else
    RESERVATION_RESPONSE=$(curl -s -X POST $BASE_URL/tickets/reserve \
      -H "Content-Type: application/json" \
      -H "Authorization: Bearer $TOKEN" \
      -d "{
        \"eventId\": \"$EVENT_ID\",
        \"quantity\": 2
      }")

    echo $RESERVATION_RESPONSE
    # Sprawdzamy, czy odpowiedź zawiera ID rezerwacji
    if [[ $RESERVATION_RESPONSE == *"reservationId"* ]]; then
        RESERVATION_ID=$(echo $RESERVATION_RESPONSE | jq -r '.reservationId 2>/dev/null')
        if [ -z "$RESERVATION_ID" ] || [ "$RESERVATION_ID" == "null" ]; then
            echo -e "${RED}Nie można uzyskać ID rezerwacji.${NC}"
            RESERVATION_ID=""
        else
            echo -e "${GREEN}Pomyślnie dokonano rezerwacji.${NC}"
        fi
    else
        echo -e "${RED}Rezerwacja biletu nie powiodła się. Odpowiedź serwera:${NC}"
        echo $RESERVATION_RESPONSE
        RESERVATION_ID=""
    fi
fi

# Sprawdzanie stanu Redis po rezerwacji
echo -e "\n${BLUE}Sprawdzanie Redis po rezerwacji:${NC}"
if [ ! -z "$RESERVATION_ID" ]; then
    RESERVATION_DATA=$(docker exec -it redis redis-cli GET "reservation:$RESERVATION_ID")
    echo "Dane rezerwacji: $RESERVATION_DATA"
    
    EVENT_SEATS=$(docker exec -it redis redis-cli GET "event:$EVENT_ID:seats")
    echo "Dostępne miejsca: $EVENT_SEATS"
    
    TEMP_SEATS=$(docker exec -it redis redis-cli GET "event:$EVENT_ID:temp_seats")
    echo "Tymczasowo zajęte miejsca: $TEMP_SEATS"
else
    echo -e "${RED}Brak ID rezerwacji. Nie można sprawdzić stanu Redis.${NC}"
fi

# Kontynuuj tylko jeśli mamy ID rezerwacji
if [ -z "$RESERVATION_ID" ]; then
    echo -e "${RED}Brak ID rezerwacji. Nie można kontynuować testów zakupu.${NC}"
else
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

    echo $PURCHASE_RESPONSE
    # Sprawdzamy, czy odpowiedź zawiera bilety
    if [[ $PURCHASE_RESPONSE == *"tickets"* ]]; then
        TICKET_ID=$(echo $PURCHASE_RESPONSE | jq -r '.tickets[0].id 2>/dev/null')
        if [ -z "$TICKET_ID" ] || [ "$TICKET_ID" == "null" ]; then
            echo -e "${RED}Nie można uzyskać ID biletu.${NC}"
            TICKET_ID=""
        else
            echo -e "${GREEN}Pomyślnie zakupiono bilet.${NC}"
        fi
    else
        echo -e "${RED}Zakup biletu nie powiódł się. Odpowiedź serwera:${NC}"
        echo $PURCHASE_RESPONSE
        TICKET_ID=""
    fi

    # 9. Pobranie biletów użytkownika
    echo -e "\n${BLUE}9. Pobranie biletów użytkownika${NC}"
    USER_TICKETS=$(curl -s -X GET $BASE_URL/tickets/my-tickets \
      -H "Authorization: Bearer $TOKEN")
    echo $USER_TICKETS

    # Sprawdzanie stanu baz po zakupie biletu
    echo -e "\n${BLUE}Sprawdzanie stanu baz danych po zakupie biletu...${NC}"
    check_database_state

    # 10. Dodawanie recenzji
    echo -e "\n${BLUE}10. Dodawanie recenzji${NC}"
    REVIEW_RESPONSE=$(curl -s -X POST $BASE_URL/events/$EVENT_ID/reviews \
      -H "Content-Type: application/json" \
      -H "Authorization: Bearer $TOKEN" \
      -d '{
        "userName": "Anna Nowak",
        "rating": 5,
        "title": "Wspaniały koncert!",
        "text": "Jeden z najlepszych koncertów na jakich byłam. Polecam!"
      }')
    echo $REVIEW_RESPONSE
    if [[ $REVIEW_RESPONSE == *"_id"* ]]; then
        echo -e "${GREEN}Pomyślnie dodano recenzję.${NC}"
    else
        echo -e "${RED}Dodawanie recenzji nie powiodło się. Odpowiedź serwera:${NC}"
        echo $REVIEW_RESPONSE
    fi

    # 11. Pobieranie recenzji wydarzenia
    echo -e "\n${BLUE}11. Pobieranie recenzji wydarzenia${NC}"
    REVIEWS=$(curl -s -X GET $BASE_URL/events/$EVENT_ID/reviews)
    echo $REVIEWS

    # Sprawdzanie stanu MongoDB po dodaniu recenzji
    echo -e "\n${BLUE}Sprawdzanie stanu MongoDB po dodaniu recenzji:${NC}"
    MONGO_CMD="mongosh"
    MONGO_EXIST=$(docker exec -it mongodb which mongosh || docker exec -it mongodb which mongo || echo "not_found")
    
    if [ "$MONGO_EXIST" = "not_found" ]; then
        echo -e "${RED}Nie można znaleźć polecenia mongosh ani mongo w kontenerze${NC}"
    else
        if [[ "$MONGO_EXIST" == */mongo ]]; then
            MONGO_CMD="mongo"
        fi
        
        docker exec -it mongodb $MONGO_CMD eventsdb --quiet --eval "db.reviews.find({eventId: \"$EVENT_ID\"}).toArray()"
    fi

    # Tylko jeśli mamy ID biletu
    if [ ! -z "$TICKET_ID" ]; then
        # 12. Anulowanie biletu
        echo -e "\n${BLUE}12. Anulowanie biletu${NC}"
        CANCEL_RESPONSE=$(curl -s -X PUT $BASE_URL/tickets/$TICKET_ID/cancel \
          -H "Authorization: Bearer $TOKEN")
        echo $CANCEL_RESPONSE
        if [[ $CANCEL_RESPONSE == *"status"*"cancelled"* ]]; then
            echo -e "${GREEN}Pomyślnie anulowano bilet.${NC}"
        else
            echo -e "${RED}Anulowanie biletu nie powiodło się. Odpowiedź serwera:${NC}"
            echo $CANCEL_RESPONSE
        fi
    else
        echo -e "${RED}Brak ID biletu. Nie można wykonać anulowania.${NC}"
    fi
fi

# Sprawdzanie stanu baz po anulowaniu biletu
echo -e "\n${BLUE}Sprawdzanie stanu baz danych po wszystkich operacjach...${NC}"
check_database_state

echo -e "\n${GREEN}Testy zostały zakończone!${NC}"

# Podsumowanie
echo -e "\n${GREEN}===== PODSUMOWANIE TESTÓW =====${NC}"

if [ ! -z "$ORGANIZER_TOKEN" ]; then
    echo -e "${GREEN}✓${NC} 1. Zarejestrowano użytkownika organizatora"
else
    echo -e "${RED}✗${NC} 1. Nie udało się zarejestrować użytkownika organizatora"
fi

if [ ! -z "$TOKEN" ]; then
    echo -e "${GREEN}✓${NC} 2. Zarejestrowano zwykłego użytkownika"
else
    echo -e "${RED}✗${NC} 2. Nie udało się zarejestrować zwykłego użytkownika"
fi

if [ ! -z "$EVENT_ID" ]; then
    echo -e "${GREEN}✓${NC} 3. Utworzono wydarzenie: Koncert Muzyki Klasycznej"
    echo -e "${GREEN}✓${NC} 4. Pobrano informacje o wydarzeniu"
else
    echo -e "${RED}✗${NC} 3. Nie udało się utworzyć wydarzenia"
    echo -e "${RED}✗${NC} 4. Nie udało się pobrać informacji o wydarzeniu"
fi

if [[ $COMMENT_RESPONSE == *"_id"* ]]; then
    echo -e "${GREEN}✓${NC} 5. Dodano komentarz do wydarzenia"
else
    echo -e "${RED}✗${NC} 5. Nie udało się dodać komentarza do wydarzenia"
fi

if [[ $COMMENTS == *"["* ]]; then
    echo -e "${GREEN}✓${NC} 6. Pobrano komentarze wydarzenia"
else
    echo -e "${RED}✗${NC} 6. Nie udało się pobrać komentarzy wydarzenia"
fi

if [ ! -z "$RESERVATION_ID" ]; then
    echo -e "${GREEN}✓${NC} 7. Dokonano rezerwacji biletów"
else
    echo -e "${RED}✗${NC} 7. Nie udało się dokonać rezerwacji biletów"
fi

if [ ! -z "$TICKET_ID" ]; then
    echo -e "${GREEN}✓${NC} 8. Zakupiono bilety"
else
    echo -e "${RED}✗${NC} 8. Nie udało się zakupić biletów"
fi

if [[ $USER_TICKETS == *"["* ]]; then
    echo -e "${GREEN}✓${NC} 9. Pobrano bilety użytkownika"
else
    echo -e "${RED}✗${NC} 9. Nie udało się pobrać biletów użytkownika"
fi

if [[ $REVIEW_RESPONSE == *"_id"* ]]; then
    echo -e "${GREEN}✓${NC} 10. Dodano recenzję wydarzenia"
else
    echo -e "${RED}✗${NC} 10. Nie udało się dodać recenzji wydarzenia"
fi

if [[ $REVIEWS == *"["* ]]; then
    echo -e "${GREEN}✓${NC} 11. Pobrano recenzje wydarzenia"
else
    echo -e "${RED}✗${NC} 11. Nie udało się pobrać recenzji wydarzenia"
fi

if [[ $CANCEL_RESPONSE == *"status"*"cancelled"* ]]; then
    echo -e "${GREEN}✓${NC} 12. Anulowano bilet"
else
    echo -e "${RED}✗${NC} 12. Nie udało się anulować biletu"
fi