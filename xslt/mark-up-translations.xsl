<!-- recognise texts which contain translations and wrap each language's content in its own text -->
<!-- so that they can be conveniently displayed side-by-side -->
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="3.0"
	xmlns="http://www.tei-c.org/ns/1.0"
	xpath-default-namespace="http://www.tei-c.org/ns/1.0">
	<xsl:mode on-no-match="shallow-copy"/>
	<xsl:template match="text[body//p/@xml:lang[. ne 'en']]">
		<text>
			<group>
				<!-- group the child elements of the body into two groups: those in English, and the rest -->
				<xsl:for-each-group select="body/*" group-by="@xml:lang='en'">
					<!-- represent each group of elements as a TEI text -->
					<text>
						<!-- tag the text which the language of the elements in the group -->
						<xsl:copy-of select="@xml:lang[1]"/>
						<body>
							<xsl:copy-of select="current-group()"/>
						</body>
					</text>
				</xsl:for-each-group>
			</group>
		</text>
	</xsl:template>
</xsl:stylesheet>