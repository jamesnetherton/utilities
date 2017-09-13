#!/usr/bin/groovy

def dir = new File(args[0])

dir.eachFile {

    def template = it.text.replaceAll("\\s+", "")
    def repo = regexMatch(template, /GIT_REPO.*?"value":"https:\/\/github.com\/.*?\/(.*?).git"/)
    def oldVersion = regexMatch(template, /APP_VERSION.*?"value":"(.*?)"/)
    def tag = regexMatch(template, /GIT_REF.*?"value":"(.*?)"/)

    println "===================> ${it.name}"
    println repo
    println oldVersion
    println tag
    println "==================="
    println ""

}

def regexMatch(String text, def regex) {
    def matcher = text =~ regex
    matcher ? matcher[0][1] : null
}

