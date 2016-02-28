package com.github.jamesnetherton.redeploy.perpetual;

import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;

import org.apache.maven.repository.internal.MavenRepositorySystemUtils;
import org.eclipse.aether.DefaultRepositorySystemSession;
import org.eclipse.aether.RepositorySystem;
import org.eclipse.aether.artifact.Artifact;
import org.eclipse.aether.artifact.DefaultArtifact;
import org.eclipse.aether.collection.CollectRequest;
import org.eclipse.aether.connector.basic.BasicRepositoryConnectorFactory;
import org.eclipse.aether.graph.Dependency;
import org.eclipse.aether.graph.DependencyFilter;
import org.eclipse.aether.graph.DependencyNode;
import org.eclipse.aether.impl.DefaultServiceLocator;
import org.eclipse.aether.repository.LocalRepository;
import org.eclipse.aether.repository.RemoteRepository;
import org.eclipse.aether.resolution.ArtifactResult;
import org.eclipse.aether.resolution.DependencyRequest;
import org.eclipse.aether.resolution.DependencyResolutionException;
import org.eclipse.aether.spi.connector.RepositoryConnectorFactory;
import org.eclipse.aether.spi.connector.transport.TransporterFactory;
import org.eclipse.aether.transport.file.FileTransporterFactory;
import org.eclipse.aether.transport.http.HttpTransporterFactory;
import org.eclipse.aether.util.artifact.JavaScopes;

public class ArtifactResolver {

    public static Artifact resolve(String gavCoordinates) {
        Utils.consoleOutput("Fetching artifact: " + gavCoordinates);

        DefaultServiceLocator locator = MavenRepositorySystemUtils.newServiceLocator();
        locator.addService(RepositoryConnectorFactory.class, BasicRepositoryConnectorFactory.class);
        locator.addService(TransporterFactory.class, FileTransporterFactory.class);
        locator.addService(TransporterFactory.class, HttpTransporterFactory.class);

        locator.setErrorHandler(new DefaultServiceLocator.ErrorHandler() {
            @Override
            public void serviceCreationFailed(Class<?> type, Class<?> impl, Throwable exception) {
                exception.printStackTrace();
            }
        });

        RepositorySystem system = locator.getService(RepositorySystem.class);
        DefaultRepositorySystemSession session = MavenRepositorySystemUtils.newSession();

        String userHome = System.getProperty("user.home");
        LocalRepository localRepo = new LocalRepository(userHome + "/.m2/repository");
        session.setLocalRepositoryManager(system.newLocalRepositoryManager(session, localRepo));

        final Artifact artifact = new DefaultArtifact(gavCoordinates);

        CollectRequest collectRequest = new CollectRequest();
        collectRequest.setRoot(new Dependency(artifact, JavaScopes.COMPILE));

        RemoteRepository mavenCentral = new RemoteRepository.Builder("central", "default", "http://central.maven.org/maven2/").build();
        RemoteRepository jbossReleases = new RemoteRepository.Builder("jboss-releases", "default", "http://repository.jboss.org/nexus/content/groups/public").build();
        RemoteRepository redhatInternal = new RemoteRepository.Builder("brew", "default", "http://download.eng.bos.redhat.com/brewroot/repos/jb-eap-6.4-rhel-6-build/latest/maven").build();
        RemoteRepository jbossThirdParty = new RemoteRepository.Builder("jboss-thirdarty", "default", "https://repository.jboss.org/nexus/content/repositories/thirdparty-releases").build();
        RemoteRepository redhatGa = new RemoteRepository.Builder("redhat-ga", "default", "http://maven.repository.redhat.com/techpreview/all").build();

        ArrayList<RemoteRepository> remoteRepositories = new ArrayList<RemoteRepository>(Arrays.asList(mavenCentral, jbossReleases, redhatInternal, jbossThirdParty, redhatGa));
        collectRequest.setRepositories(remoteRepositories);

        DependencyRequest dependencyRequest = new DependencyRequest(collectRequest, new DependencyFilter() {
            public boolean accept(DependencyNode dependencyNode, List<DependencyNode> list) {
                return dependencyNode.getArtifact().getGroupId().equals(artifact.getGroupId()) &&
                dependencyNode.getArtifact().getArtifactId().equals(artifact.getArtifactId());
            }
        });
        List<ArtifactResult> artifactResults = null;
        try {
            artifactResults = system.resolveDependencies(session, dependencyRequest).getArtifactResults();
        } catch (DependencyResolutionException e) {
            Utils.consoleOutput("Failed to resolve: " + gavCoordinates);
        }

        return artifactResults.get(0).getArtifact();
    }
}
