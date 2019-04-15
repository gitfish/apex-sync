public class RemoteDatabase {
    
    public class VersionInfo {
        String version;
        String label;
        String url;
    }

    public class QueryResult {
        Integer totalSize;
        Boolean done;
        List<sObject> records;
        String nextRecordsUrl;
    }

    public class IteratorException extends Exception {}

    public class QueryIterator implements Iterator<sObject> {
        private IQueryClient client;
        private String soql;
        private QueryResult currentResult;
        private Integer currentResultIndex = 0;
        public QueryIterator(IQueryClient client, String soql) {
            this.client = client;
            this.soql = soql;
        }
        public Boolean hasNext() {
            if(currentResult == null) {
                currentResult = client.query(soql);
            }
            return (currentResult.records != null && currentResultIndex < currentResult.records.size()) || currentResult.nextRecordsUrl != null;
        }
        public sObject next() {
            if(currentResult == null) {
                currentResult = client.query(soql);
            }
            if((currentResult.records == null || currentResultIndex == currentResult.records.size()) && currentResult.nextRecordsUrl != null) {
                currentResult = client.queryNext(currentResult.nextRecordsUrl);
                currentResultIndex = 0;
            }
            if(currentResult.records != null && currentResultIndex < currentResult.records.size()) {
                Integer resultIndex = currentResultIndex;
                currentResultIndex ++;
                return currentResult.records.get(resultIndex);
            }
            throw new IteratorException();
        }
    }

    public class QueryIterable implements Iterable<sObject> {
        private IQueryClient client;
        private String soql;
        public QueryIterable(IQueryClient client, String soql) {
            this.client = client;
            this.soql = soql;
        }
        public Iterator<sObject> iterator() {
            return new QueryIterator(client, soql);
        }
    }

    public interface IQueryClient {
        QueryResult query(String soql);
        QueryResult queryNext(String nextRecordsUrl);
    }

    public class Client implements IQueryClient {
        String username;
        String loginUrl;
        String consumerKey;
        String instanceUrl;
        private String accessToken;
        private List<VersionInfo> allVersionsInternal;
        private VersionInfo latestVersionInternal;
        public Client() {}
        public Client(String username, String loginUrl, String consumerKey, String instanceUrl) {
            this.username = username;
            this.loginUrl = loginUrl;
            this.consumerKey = consumerKey;
            this.instanceUrl = instanceUrl;
        }
        private void setupRequest(HttpRequest req) {
            req.setHeader('Authorization', 'Bearer ' + accessToken);
        }
        public void connect() {
            if(accessToken == null) {
                Auth.JWT jwt = new Auth.JWT();
                jwt.setSub(this.username);
                jwt.setAud(this.loginUrl);
                jwt.setIss(this.consumerKey);

                Auth.JWS jws = new Auth.JWS(jwt, 'Apex_Sync');

                String tokenEndpoint = this.loginUrl + '/services/oauth2/token';

                Auth.JWTBearerTokenExchange bearer = new Auth.JWTBearerTokenExchange(tokenEndpoint, jws);

                accessToken = bearer.getAccessToken();
            }
        }
        public List<VersionInfo> allVersionInfo {
            get {
                if(this.allVersionsInternal == null) {
                    this.connect();
                    HttpRequest req = new HttpRequest();
                    setupRequest(req);
                    req.setMethod('GET');
                    req.setEndpoint(this.instanceUrl + '/services/data/');

                    Http http = new Http();
                    HttpResponse res = http.send(req);
                    this.allVersionsInternal = (List<VersionInfo>) JSON.deserialize(res.getBody(), List<VersionInfo>.class);
                }
                return this.allVersionsInternal;
            }
        }
        public VersionInfo latestVersionInfo {
            get {
                if(this.latestVersionInternal == null) {
                    VersionInfo info;
                    Decimal latestVersion;
                    for(VersionInfo vi : this.allVersionInfo) {
                        Decimal ver = Decimal.valueOf(vi.version);
                        if(latestVersion == null || ver > latestVersion) {
                            latestVersion = ver;
                            info = vi;
                        }
                    }
                    this.latestVersionInternal = info;
                }
                return this.latestVersionInternal;
            }
        }
        public String getRaw(String path) {
            connect();
            String endpoint = instanceUrl + path;
            HttpRequest req = new HttpRequest();
            setupRequest(req);
            req.setMethod('GET');
            req.setEndpoint(endpoint);

            Http http = new Http();
            HttpResponse res = http.send(req);
            return res.getBody();
        }
        public String queryRaw(String soql) {
            return getRaw(latestVersionInfo.url + '/query?q=' + EncodingUtil.urlEncode(soql, 'UTF-8'));
        }
        public QueryResult parseQueryResult(String raw) {
            return (QueryResult) JSON.deserialize(raw, QueryResult.class);
        }
        public QueryResult query(String soql) {
            return parseQueryResult(queryRaw(soql));
        }
        public String queryNextRaw(String nextRecordsUrl) {
            return getRaw(nextRecordsUrl);
        }
        public String queryNextRaw(QueryResult cursor) {
            return queryNextRaw(cursor.nextRecordsUrl);
        }
        public QueryResult queryNext(String nextRecordsUrl) {
            return parseQueryResult(queryNextRaw(nextRecordsUrl));
        }
        public Iterable<sObject> queryIterable(String soql) {
            return new QueryIterable(this, soql);
        }
        public Iterator<sObject> queryIterator(String soql) {
            return new QueryIterator(this, soql);
        }
    }
}
