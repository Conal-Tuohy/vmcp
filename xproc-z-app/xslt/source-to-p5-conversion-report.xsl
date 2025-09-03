<?xml version="1.1"?>
<xsl:stylesheet version="3.0" 
	expand-text="yes"
	xmlns:xsl="http://www.w3.org/1999/XSL/Transform" 
	xmlns:c="http://www.w3.org/ns/xproc-step" 
	xmlns="http://www.w3.org/1999/xhtml">
	
	<xsl:variable name="title" select=" 'Ingestion report' "/>
	
	<xsl:variable name="ingested" select="//c:file[not(c:errors)]"/>
	<xsl:variable name="failed" select="//c:file[c:errors]"/>

	<xsl:template match="/c:directory">
		<html>
			<head>
				<title>{$title}</title>
			</head>
			<body>
				<main>
					<h1>{$title}</h1>
					<p>Files ingested: {count($ingested)}.</p>
					<xsl:if test="$failed">
						<h2>Errors</h2>
						<p>See <a href="https://www.w3.org/TR/xproc/#app.step-errors">Error Codes</a></p>
						<p>Files which were not ingested: {count($failed)}.</p>
						<xsl:if test="count($failed) gt 100">
							<p>Showing first 100 errors only.</p>
						</xsl:if>
						<ul>
							<xsl:for-each select="$failed[position() le 100]">
								<li>{resolve-uri(@name, @xml:base)} failed with error {c:errors/c:error}</li>
							</xsl:for-each>
						</ul>
					</xsl:if>
				</main>
			</body>
		</html>
	</xsl:template>
	
</xsl:stylesheet>
