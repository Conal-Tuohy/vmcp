<?xml version="1.1"?>
<xsl:stylesheet version="2.0" 
	xmlns:xsl="http://www.w3.org/1999/XSL/Transform" 
	xmlns:c="http://www.w3.org/ns/xproc-step" 
	xmlns="http://www.w3.org/1999/xhtml">
	
	<xsl:param name="corpus-base-uri"/>

	<xsl:template match="/c:directory">
		<html>
			<head>
				<title>Directory of texts</title>
				<style type="text/css">
					.pale {
						color: #E0E0E0;
						font-weight: bold;
					}
					tr:nth-child(even) .pale {
						color: #FFFFFF;
					}
					table {
					}
					td {
						padding-left: 1em;
						padding-right: 1em;
						padding-top: 0.5em;
						padding-bottom: 0.5em;
					}
					tr:nth-child(even) {
						background-color: #E0E0E0;
					}
				</style>
			</head>
			<body xsl:expand-text="true">
				<h1>List of texts</h1>
				<table>
					<xsl:comment><xsl:value-of select="$corpus-base-uri"/></xsl:comment>
					<xsl:for-each select="//c:file">
						<xsl:sort select="@name"/>
						<xsl:variable name="file-name" select="@name"/>
						<xsl:variable name="file-relative-uri" select="encode-for-uri($file-name)"/>
						<xsl:variable name="file-absolute-uri" select="resolve-uri($file-relative-uri, @xml:base)"/>
						<!-- compute an identifier for the document to use in Solr:
							get the URI of the XML document relative to the corpus root folder, 
							strip off the '.xml' extension
						-->
						<xsl:variable name="file-id" select="substring-before(substring-after($file-absolute-uri, $corpus-base-uri), '.xml')"/>
						<tr>
							<td>
								<xsl:for-each select="tokenize($file-id, '/')"><span class="pale">/</span>{.}</xsl:for-each>
							</td>
							<td><a href="{$file-id}.xml">XML</a></td>
							<td><a href="../text/{$file-id}/">HTML</a></td>
							<td><a href="../solr/{$file-id}.xml">Solr</a></td>
							<td><a href="../iiif/{$file-id}/manifest">IIIF</a></td>
						</tr>
					</xsl:for-each>
				</table>
			</body>
		</html>
	</xsl:template>
	
		
</xsl:stylesheet>
