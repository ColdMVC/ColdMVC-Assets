<cfif thisTag.executionMode eq "end">
	<cfparam name="attributes.name" default="application" />	
	<cfset thisTag.generatedContent = coldmvc.framework.getBean("assetManager").renderPackage(attributes.name) />
</cfif>