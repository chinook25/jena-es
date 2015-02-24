DATA=http://localhost:8080/datasets/hello/data
QUERY=http://localhost:8080/datasets/hello/query
UPDATE=http://localhost:8080/datasets/hello/update
GRAPH=http://trials.drugis.org/studies/9c7bb39e-441c-4a64-a6b9-615f51eb046a

V1=http://drugis.org/eventSourcing/event/4818e24b-50fe-42ce-babc-ffe3569e3da5
V2=http://drugis.org/eventSourcing/event/3156c8c6-df88-4352-9f29-a1dbddfe0278
LABEL=http://www.w3.org/2000/01/rdf-schema#label

# Content-Type negotiation for graph store retrieval

curl -D headers-current-xml -H "Accept: application/rdf+xml" $DATA?graph=$GRAPH > body-current.xml
curl -D headers-current-ttl -H "Accept: text/turtle" $DATA?graph=$GRAPH > body-current.ttl

# Version negotiation for graph store retrieval

curl -D headers-v1-ttl -H "Accept: text/turtle" -H "X-Accept-EventSource-Version: $V1" $DATA?graph=$GRAPH > body-v1.ttl
curl -D headers-v2-ttl -H "Accept: text/turtle" -H "X-Accept-EventSource-Version: $V2" $DATA?graph=$GRAPH > body-v2.ttl

# Simple SPARQL query

curl -G -D headers-current-query \
  --data-urlencode "query=SELECT * WHERE { GRAPH <$GRAPH> { <$GRAPH> ?p ?o }} LIMIT 10" \
  $QUERY

# Version negotiation for SPARQL queries

curl -G -H "X-Accept-EventSource-Version: $V1" \
  --data-urlencode "query=SELECT * WHERE { GRAPH <$GRAPH> { <$GRAPH> <$LABEL> ?o }}" \
  $QUERY

curl -G -H "X-Accept-EventSource-Version: $V2" \
  --data-urlencode "query=SELECT * WHERE { GRAPH <$GRAPH> { <$GRAPH> <$LABEL> ?o }}" \
  $QUERY

# Content-Type negotiation for SPARQL results

curl -G -H "X-Accept-EventSource-Version: $V2" \
  -H "Accept: application/sparql-results+json" \
  --data-urlencode "query=SELECT * WHERE { GRAPH <$GRAPH> { <$GRAPH> <$LABEL> ?o }}" \
  $QUERY

curl -G -H "X-Accept-EventSource-Version: $V2" \
  -H "Accept: application/sparql-results+xml" \
  --data-urlencode "query=SELECT * WHERE { GRAPH <$GRAPH> { <$GRAPH> <$LABEL> ?o }}" \
  $QUERY

curl -G -H "X-Accept-EventSource-Version: $V2" \
  -H "Accept: text/plain" \
  --data-urlencode "query=SELECT * WHERE { GRAPH <$GRAPH> { <$GRAPH> <$LABEL> ?o }}" \
  $QUERY

# Construct query

curl -G -H "Accept: application/rdf+xml" \
  --data-urlencode "query=CONSTRUCT { <$GRAPH> ?p ?o } WHERE { GRAPH <$GRAPH> { <$GRAPH> ?p ?o }}" \
  $QUERY

# Ask queries

## Should return true
curl -G -H "X-Accept-EventSource-Version: $V2" \
  -H "Accept: text/plain" \
  --data-urlencode "query=ASK { GRAPH <$GRAPH> { <$GRAPH> <$LABEL> \"De Nayer, A et al, 2002\" }}" \
  $QUERY

## Should return false
curl -G -H "X-Accept-EventSource-Version: $V2" \
  -H "Accept: application/sparql-results+json" \
  --data-urlencode "query=ASK { GRAPH <$GRAPH> { <$GRAPH> <$LABEL> \"De Nayer et al, 2002\" }}" \
  $QUERY

## Should return true 
curl -G -H "X-Accept-EventSource-Version: $V1" \
  -H "Accept: application/sparql-results+xml" \
  --data-urlencode "query=ASK { GRAPH <$GRAPH> { <$GRAPH> <$LABEL> \"De Nayer et al, 2002\" }}" \
  $QUERY

# Describe query

curl -G -H "X-Accept-EventSource-Version: $V2" \
  -H "Accept: text/turtle" \
  --data-urlencode "query=DESCRIBE <$GRAPH>" \
  $QUERY

# Invalid query (expect a 400 Bad Request + explanatory text body)

curl -G -D invalid-query.txt \
  --data-urlencode "query=PREFIX foaf: <http://xmlns.com/foaf/0.1/> SELECT ?name WHERE { ?x foaf:name ?name ORDER BY ?name }" \
  $QUERY

curl -H "Content-Type: application/sparql-update" -D invalid-update.txt \
  --data "PREFIX foaf: <http://xmlns.com/foa/> SELECT ?name WHERE { ?x foaf:name ?name ORDER BY ?name }" $UPDATE

# Update old version (expect 409 Conflict)

curl -H "X-Accept-EventSource-Version: $V1" -H "Content-Type: application/sparql-update" -D update-old.txt \
  --data "INSERT DATA { <a> <b> <c> }" $UPDATE

# Insert some data

function extract {
  grep "X-EventSource-Version: " | sed 's/X-EventSource-Version: //'
}

LATEST=$(curl -s -D - -H "Accept: text/turtle" $DATA?graph=$GRAPH -o /dev/null | extract)

curl -H "X-Accept-EventSource-Version: $LATEST" -H "Content-Type: application/sparql-update" -D update-new.txt \
  --data "INSERT DATA { GRAPH <http://example.com/> { <a> <b> <c> } }" $UPDATE

UPDATED=$(extract <update-new.txt)

curl -H "Accept: text/turtle" -H "X-Accept-EventSource-Version: $LATEST" $DATA?graph=http://example.com/
curl -H "Accept: text/turtle" -H "X-Accept-EventSource-Version: $UPDATED" $DATA?graph=http://example.com/

curl -s -D - -X PUT -H "Content-Type: text/turtle" -H "X-Accept-EventSource-Version: $UPDATED" \
  --data "<a> <b> <d>" $DATA?graph=http://example.com/

curl -H "Accept: text/turtle" $DATA?graph=http://example.com/

curl -s -D - -X POST -H "Content-Type: text/turtle" --data "<a> <b> <e>" $DATA?graph=http://example.com/

curl -H "Accept: text/turtle" $DATA?graph=http://example.com/

curl -s -D - -X DELETE $DATA?graph=http://example.com/

curl -I -H "Accept: text/turtle" $DATA?graph=http://example.com/
