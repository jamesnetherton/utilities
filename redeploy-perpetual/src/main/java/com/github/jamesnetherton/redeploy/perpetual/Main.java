package com.github.jamesnetherton.redeploy.perpetual;

import java.io.File;
import java.io.FileInputStream;
import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.ArrayList;
import java.util.List;
import java.util.zip.ZipEntry;
import java.util.zip.ZipInputStream;

import org.eclipse.aether.artifact.Artifact;
import org.kohsuke.args4j.Argument;
import org.kohsuke.args4j.CmdLineException;
import org.kohsuke.args4j.CmdLineParser;
import org.kohsuke.args4j.Option;

public class Main {

    @Option(name = "--install-dir", usage = "The path to the application server installation directory")
    private File installationDirectory = Paths.get(System.getProperty("java.io.tmpdir"), "appserver").toFile();

    @Option(name = "--server-version", usage = "The application server version")
    private String serverVersion;

    @Option(name = "--installer-version", usage = "The installer version")
    private String installerVersion;

    @Option(name = "--head-dump-directory", usage = "Location of heap dump output if OutOfMemoryError is encountered")
    private File heapDumpDirectory = Paths.get(installationDirectory.getAbsolutePath()).toFile();

    @Option(name = "--redeploy-period", usage = "The duration between redeploys")
    private Long redeployPeriod = 15000L;

    @Option(name = "--max-redeploys", usage = "The maximum number of redeploys before exiting")
    private Integer maxRedeploys = 50;

    @Option(name = "--max-metaspace-size", usage = "The maximum size of the application server metaspace in megabytes")
    private Integer maxMetaspaceSize = 115;

    @Option(name = "--run-installer", usage = "Whether or not to run the installer application")
    private String runInstaller = "true";

    @Argument
    private List<String> arguments = new ArrayList<String>();

    public static void main(String... args) throws Exception {
        new Main().doMain(args);
    }

    public void doMain(String... args) {

        CmdLineParser parser = new CmdLineParser(this);
        try {
            parser.parseArgument(args);
        } catch (CmdLineException e) {
            e.getParser().printUsage(System.out);
            return;
        }

        String serverGroupId = "org.jboss.as";
        String serverArtifactId = "jboss-as-dist";

        String installerGroupId = "com.redhat.fuse.eap";
        String installerArtifactId = "fuse-eap-installer";

        String appServerGav = Utils.createGavCordinates(serverGroupId, serverArtifactId, "zip", serverVersion);
        String installerGav = Utils.createGavCordinates(installerGroupId, installerArtifactId, "jar", installerVersion);

        Artifact server = ArtifactResolver.resolve(appServerGav);
        Artifact installer = ArtifactResolver.resolve(installerGav);

        if (!installationDirectory.exists()) {
            installationDirectory.mkdir();
        }

        final File cachedAppServerZip = Paths.get(installationDirectory.getPath(), server.getFile().getName()).toFile();
        try {
            if (!cachedAppServerZip.exists()) {
                Utils.consoleOutput("Copying application server archive to: " + cachedAppServerZip.toPath());
                Files.copy(server.getFile().toPath(), cachedAppServerZip.toPath());

                Utils.consoleOutput("Extracting application server archive");
                Utils.unzipFile(cachedAppServerZip.toString(), installationDirectory.toString());
            }

            ZipInputStream zipIn = new ZipInputStream(new FileInputStream(cachedAppServerZip.toString()));
            ZipEntry entry = zipIn.getNextEntry();
            zipIn.close();

            final Path jbossHome = installationDirectory.toPath().resolve(entry.getName());

            if (Boolean.parseBoolean(runInstaller)) {
                File cachedInstaller = Paths.get(jbossHome.toString(), installer.getFile().getName()).toFile();
                if (!cachedInstaller.exists()) {
                    Utils.consoleOutput("Copying application installer to: " + cachedInstaller.toPath());
                    Files.copy(installer.getFile().toPath(), jbossHome.resolve(cachedInstaller.getName()));
                }

                Utils.consoleOutput("Running application installer");
                ProcessBuilder installerProcessBuilder = new ProcessBuilder();
                installerProcessBuilder.directory(jbossHome.toFile());
                installerProcessBuilder.command("java", "-jar", cachedInstaller.getName(), ".");

                Process installerProcess = installerProcessBuilder.start();
                installerProcess.waitFor();

                if (installerProcess.exitValue() != 0) {
                    Utils.consoleOutput("Application installer failed");
                    System.exit(1);
                }
            }

            List<String> appServerStartupCmd = new ArrayList<String>();
            String standaloneScriptExtension = "sh";
            if (Utils.isWindows()) {
                standaloneScriptExtension = "bat";
            } else {
                appServerStartupCmd.add("/bin/sh");
            }

            String finalStandaloneScriptExtension = standaloneScriptExtension;
            String standaloneScriptName = "standalone." + finalStandaloneScriptExtension;
            Path jbossBin = jbossHome.resolve("bin");
            File standaloneScript = jbossBin.resolve(standaloneScriptName).toFile();
            if (!standaloneScript.canExecute()) {
                Utils.consoleOutput("Making " + standaloneScriptName + " executable");
                standaloneScript.setExecutable(true);
            }

            File heapDumpFile = heapDumpDirectory.toPath().resolve("heapdump-" + Utils.getUniqueFileSuffix() + ".hprof").toFile();
            String javaOpts = "-XX:MaxMetaspaceSize=" + maxMetaspaceSize + "m -XX:+HeapDumpOnOutOfMemoryError -XX:HeapDumpPath=" + heapDumpFile.getAbsolutePath() + " -Djava.net.preferIPv4Stack=true";
            appServerStartupCmd.add(standaloneScriptName);

            Utils.consoleOutput("Starting appplication server with options: " + javaOpts);
            ProcessBuilder appServerProcessBuilder = new ProcessBuilder();
            appServerProcessBuilder.directory(jbossBin.toFile());
            appServerProcessBuilder.command(appServerStartupCmd.toArray(new String[]{}));
            appServerProcessBuilder.environment().put("JAVA_OPTS", javaOpts);

            // Handle weirdness on *nix where stuff randomly stops working after a few redeploys
            if (!Utils.isWindows()) {
                File devNull = new File("/dev/null");
                appServerProcessBuilder.redirectOutput(devNull);
                appServerProcessBuilder.redirectError(devNull);
            }

            Process process = appServerProcessBuilder.start();

            while (!Utils.isServerRunning()) {
                Utils.consoleOutput("Waiting for application server to start...");
                Thread.sleep(1000);
            }

            Utils.consoleOutput("Let's get ready to rumble!");

            int deployCount = 1;
            while (deployCount <= maxRedeploys) {
                Utils.consoleOutput("Starting application redeployment. Attempt " + deployCount + " of " + maxRedeploys);

                for (String arg : arguments) {
                    Utils.redeployApplication(arg);
                }

                if (heapDumpFile.exists()) {
                    Utils.consoleOutput("Heap dump detected - manual cleanup of application server process is required");
                    Utils.consoleOutput("Exiting after " + deployCount + " redeploys");
                    System.exit(0);
                }

                Utils.consoleOutput("Waiting " + (redeployPeriod / 1000) + " seconds for next redeployment...");
                Thread.sleep(redeployPeriod);

                deployCount++;
            }

            Utils.consoleOutput("Stopping application server");
            process.destroyForcibly().waitFor();
        } catch (IOException e) {
            e.printStackTrace();
        } catch (InterruptedException e) {
            e.printStackTrace();
        }
    }
}
