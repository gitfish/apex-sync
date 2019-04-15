public class RemoteDatabaseSample {
    public static RemoteDatabase.Client newSampleClient() {
        return new RemoteDatabase.Client(
            'mfisher@dev.one',
            'https://login.salesforce.com',
            '3MVG9pe2TCoA1Pf6I1c1KhtCP9xqdMMjCHw.i3Umujmx8T4MUusx.cg8aGEABY9hLQj0FUq1fh8rheZEMGONh',
            'https://mfisher-one-dev-ed.my.salesforce.com'
        );
    }
}
