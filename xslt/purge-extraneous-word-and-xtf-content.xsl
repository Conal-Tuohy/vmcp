<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="3.0"
	xmlns:c="http://www.w3.org/ns/xproc-step" 
	xmlns:tei="http://www.tei-c.org/ns/1.0">
	<!-- remove paragraphs which contain metadata fields and are relics of the Word-conversion process,
	as well as the incipit headings which were added for XTF's benefit -->
	<xsl:mode on-no-match="shallow-copy"/>
	<!-- XTF required that a document contain at least one div with a head -->
	<xsl:template match="tei:head[@type='incipit']"/>
	<xsl:template match="tei:body/tei:div[@xml:id='main']">
		<xsl:apply-templates/>
	</xsl:template>
	<!-- these are elements in the text of the Word document which contain metadata. The values have already been copied into the teiHeader -->
	<xsl:template match="(tei:p|tei:ab)[@rend=('number', 'correspondent', 'location', 'Progress%20note', 'Plant%20names', 'plant%20names')]"/>
</xsl:stylesheet>