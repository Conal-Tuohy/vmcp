<?xml version="1.1"?>
<xsl:stylesheet version="2.0" 
	xmlns:xsl="http://www.w3.org/1999/XSL/Transform" 
	xmlns:c="http://www.w3.org/ns/xproc-step" 
	xmlns:xs="http://www.w3.org/2001/XMLSchema"
	xmlns:solr="tag:conaltuohy.com,2021:solr"
	xmlns:f="http://www.w3.org/2005/xpath-functions"
	exclude-result-prefixes="xs solr">

	<xsl:param name="solr-base-uri"/>
	<xsl:param name="default-results-limit" required="true"/>	
	
	<xsl:import href="normalize-solr-query-string.xsl"/>
	
	<!-- Transform the user's HTTP request into an outgoing HTTP request to Solr using Solr's JSON request API 
	https://lucene.apache.org/solr/guide/7_6/json-request-api.html -->
	
	<!-- The incoming request has been parsed into a set of parameters i.e. c:param-set, and aggregated with the field definitions -->
	<!-- We construct an HTTP POST request to Solr, containing a query derived from the search parameters received from the HTML search form -->

	<!-- the document/field elements are the definitions of the fields in the schema -->
	<xsl:variable name="fields" select="/*/document/field"/>
	<!-- The param-set contains the names and values of the fields sent by the HTML search form --> 
	<xsl:variable name="parameters" select="/*/c:param-set/c:param"/>
	
	<xsl:template match="/">
		<c:request method="post" href="{$solr-base-uri}query">
			<c:body content-type="application/xml">
				<!-- The field named "text" is used to query the full text (the other fields are document-level metadata) -->
				<xsl:variable name="text-query" select="solr:normalize-query-string($parameters[@name='text']/@value)"/>
				<f:map>
					<f:map key="params">
						<xsl:if test="$text-query">
							<!-- only if we have a "text" query parameter, and are therefore searching the full text, does it make sense to request hit-highlighting: -->
							<f:boolean key="hl">true</f:boolean>
							<f:boolean key="hl.mergeContiguous">true</f:boolean><!-- please merge adjacent hits together into one large hit -->
							<f:string key="hl.fl">normalized</f:string><!-- comma separated list of the full-text fields we want Solr to generate highlights within -->
							<f:string key="hl.q">text:<xsl:value-of select="$text-query"/></f:string>
							<f:string key="hl.snippets">10</f:string>
							<f:number key="hl.maxAnalyzedChars">-1</f:number><!-- analyze the entire text -->
						</xsl:if>
					</f:map>
					<f:string key="query">*:*</f:string>
					<!-- request only the values of certain fields -->
					<f:string key="fields">id title author recipient day</f:string>
					<!-- the Solr 'offset' and 'limit' query parameters control pagination -->
					<!-- if 'page' is blank, then it counts as 1. e.g. if $default-results-limit=2 and page=1 then offset=2*(1-1)=0 -->
					<xsl:variable name="page" select=" number(($parameters[@name='page']/@value, 1)[1]) "/>
					<f:number key="offset"><xsl:value-of select="$default-results-limit * ($page - 1)"/></f:number>
					<f:number key="limit"><xsl:value-of select="$default-results-limit"/></f:number>
					<!-- Any parameter other than 'page' is assumed to a field in Solr -->
					<xsl:variable name="control-parameter-names" select="('page')"/>
					<xsl:variable name="search-fields" select="$parameters[not(@name = $control-parameter-names)]"/>
					<!-- impose a sort order; sort by descending score, then by the value of the "sort" field, ascending -->
					<f:string key="sort">score desc, sort asc</f:string>
					<f:array key="filter">
						<!-- loop through all the fields whose normalized query string is non null, and transform to JSON -->
						<xsl:for-each-group group-by="@name" select="$search-fields[solr:normalize-query-string(@value)]">
							<!-- the param/@name specifies the field's name; look up the field by name and get field's definition -->
							<xsl:variable name="field-name" select="@name"/>
							<xsl:variable name="field-value" select="@value"/>
							<xsl:variable name="field-definition" select="$fields[@name=$field-name]"/>
							<xsl:variable name="field-range" select="$field-definition/@range"/>
							<xsl:choose>
								<xsl:when test="$field-range">
									<f:string><xsl:value-of select="
										concat(
											'{!tag=', $field-name, '}', 
											string-join(
												for $field-value in current-group()/@value return concat(
													$field-name, 
													':[&quot;', 
													$field-value,
													'/', $field-range,
													'&quot; TO &quot;',
													$field-value,
													'/', $field-range, '+1', $field-range,
													'&quot;]'
												),
												' OR '
											)
										)
									"/></f:string>
								</xsl:when>
								<xsl:when test="$field-definition/@type='facet'">
									<f:string><xsl:value-of select="
										concat(
											'{!tag=', $field-name, '}', 
											string-join(
												for $field-value in current-group()/@value return concat(
													$field-name, ':&quot;',$field-value, '&quot;'
												),
												' OR '
											)
										)
									"/></f:string>
								</xsl:when>
								<xsl:otherwise>
									<f:string><xsl:value-of select="
										concat(
											'{!tag=', $field-name, '}', 
											string-join(
												for $field-value in current-group()/@value return concat(
													$field-name, ':(',solr:normalize-query-string($field-value), ')'
												),
												' OR '
											)
										)
									"/></f:string>
								</xsl:otherwise>
							</xsl:choose>
						</xsl:for-each-group>
					</f:array>
					<xsl:call-template name="render-facets-query">
						<xsl:with-param name="facets" select="$fields[@type='facet']"/>
					</xsl:call-template>
				</f:map>
			</c:body>
		</c:request>
	</xsl:template>
	
	<!-- render a set of facets as a facet query, as in https://solr.apache.org/guide/8_8/json-facet-api.html -->
	<xsl:template name="render-facets-query">
		<xsl:param name="facets"/>
		<f:map key="facet">
			<xsl:for-each select="$facets">
				<f:map key="{@name}">
					<xsl:if test="@missing"><!-- include a count of records which are missing a value for this facet -->
						<f:boolean key="missing">true</f:boolean>
					</xsl:if>
					<xsl:choose>
						<xsl:when test="range">
							<!-- facet/range specifies a range unit; either MONTH, DAY, or YEAR -->
							<f:string key="type">range</f:string>
							<!-- e.g. "NOW/DAY-1MONTH", "NOW/MONTH-1YEAR" -->
							<f:string key="start"><xsl:value-of select="concat('NOW/', range, start)"/></f:string>
							<!-- e.g. "+1DAY", "+1MONTH" -->
							<f:string key="gap"><xsl:value-of select="concat('+1', range)"/></f:string>
							<!-- e.g. "NOW/+1DAY", "NOW/+1MONTH" -->
							<f:string key="end"><xsl:value-of select="concat('NOW/', range, '+1', range)"/></f:string>
						</xsl:when>
						<xsl:otherwise>
							<f:string key="type">terms</f:string>
						</xsl:otherwise>
					</xsl:choose>
					<f:string key="field"><xsl:value-of select="@name"/></f:string>
					<f:number key="mincount">0</f:number>
					<f:number key="limit">4000</f:number>
					<f:boolean key="numBuckets">true</f:boolean>
					<!-- render nested facets -->
					<!-- Hiearchical facets work slightly differently to flat facets -->
					<!-- Firstly they are exclusive in the sense that you can only choose one bucket within a given level at a time -->
					<xsl:variable name="is-hierarchical-facet" select="boolean(ancestor::field | descendant::field)"/>
					<xsl:choose>
						<xsl:when test="$is-hierarchical-facet">
						</xsl:when>
						<xsl:otherwise>
							<!-- In a non-hierarchical facet, an existing selection does not constrain the domain of the facet; i.e. 
							selecting a given bucket within the facet will not exclude buckets which don't co-occur with the selected
							bucket -->
							<f:map key="domain">
								<f:string key="excludeTags"><xsl:value-of select="@name"/></f:string>
							</f:map>
						</xsl:otherwise>
					</xsl:choose>
					<!-- 
						Only query for nested facets if we have a constraint on the parent facet
						e.g. if we have a "decade" parent facet containing a "year" child facet, but the user hasn't specified a particular decade,
						then we shouldn't query for decades. But if the user has specified e.g. decade=1880s, then we SHOULD query for the
						"year" facet, with the domain constrained to decade=1880s
					-->
					<xsl:if test="@name = $parameters[normalize-space(@value)]/@name"><!-- TODO test that this condition is doing the trick -->
						<xsl:variable name="nested-facets" select="field"/>
						<xsl:if test="$nested-facets">
							<xsl:call-template name="render-facets-query">
								<xsl:with-param name="facets" select="$nested-facets"/>
							</xsl:call-template>
						</xsl:if>
					</xsl:if>
				</f:map>
			</xsl:for-each>
		</f:map>
	</xsl:template>
	
</xsl:stylesheet>
