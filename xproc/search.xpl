<p:library version="1.0" 
	xmlns:p="http://www.w3.org/ns/xproc" 
	xmlns:c="http://www.w3.org/ns/xproc-step" 
	xmlns:cx="http://xmlcalabash.com/ns/extensions"
	xmlns:pxf="http://exproc.org/proposed/steps/file"
	xmlns:z="https://github.com/Conal-Tuohy/XProc-Z" 
	xmlns:chymistry="tag:conaltuohy.com,2018:chymistry"
	xmlns:fn="http://www.w3.org/2005/xpath-functions"
	xmlns:html="http://www.w3.org/1999/xhtml">
	
	<p:import href="http://xmlcalabash.com/extension/steps/library-1.0.xpl"/>
	<p:import href="xproc-z-library.xpl"/>
	
	<p:declare-step name="highlight-hits" type="chymistry:highlight-hits">
		<p:input port="source"/>
		<p:output port="result"/>
		<p:option name="highlight"/>
		<p:option name="id"/>
		<p:option name="solr-base-uri" required="true"/>
		<cx:message>
			<p:with-option name="message" select="$highlight"/>
		</cx:message>
		<p:choose>
			<p:when test="$highlight">
				<!-- highlighting is required -->
				<p:viewport name="searchable-content" match="html:div[@class='searchable-content']">
					<p:xslt name="measured-text">
						<p:input port="parameters"><p:empty/></p:input>
						<p:input port="stylesheet">
							<p:document href="../xslt/measure-text-nodes-for-highlighting.xsl"/>
						</p:input>
					</p:xslt>
					<p:xslt name="solr-highlight-query">
						<p:with-param name="view" select=" 'text' "/>
						<p:with-param name="id" select="$id"/>
						<p:with-param name="solr-base-uri" select="$solr-base-uri"/>
						<p:with-param name="highlight" select="$highlight"/>
						<p:input port="stylesheet">
							<p:document href="../xslt/create-solr-highlight-query.xsl"/>
						</p:input>
						<p:input port="source">
							<p:inline><dummy/></p:inline>
						</p:input>
					</p:xslt>
					<p:http-request name="solr-highlight-results"/>
					<p:wrap-sequence wrapper="html-and-highlight-strings">
						<p:input port="source">
							<p:pipe step="solr-highlight-results" port="result"/>
							<p:pipe step="measured-text" port="result"/>
						</p:input>
					</p:wrap-sequence>
					<p:xslt name="mark-up-highlights-in-html">
						<p:input port="parameters"><p:empty/></p:input>
						<p:input port="stylesheet">
							<p:document href="../xslt/mark-up-highlights.xsl"/>
						</p:input>
					</p:xslt>
					<p:xslt name="link-hits-into-sequence">
						<p:input port="parameters"><p:empty/></p:input>
						<p:input port="stylesheet">
							<p:document href="../xslt/link-highlights-into-sequence.xsl"/>
						</p:input>
					</p:xslt>
				</p:viewport>
			</p:when>
			<p:otherwise>
				<p:identity name="no-highlighting-required"/>
			</p:otherwise>
		</p:choose>
	</p:declare-step>
	
	<p:declare-step name="resolve-document-identifier" type="chymistry:resolve-document-identifier">
		<p:input port="source"/>
		<p:output port="result"/>
		<p:option name="solr-base-uri" required="true"/>
		<p:variable name="document-identifier" select="substring-after(/c:request/@href, '/id/')"/>
		<!-- returns an HTTP redirect to the page of a document identified by its 'document-identifier' field in Solr -->
		<!-- generate a Solr query to look up a document by document-identifier field, e.g.
		http://localhost:8983/solr/vmcp/select?fl=id&q=document-identifier%3A%2257-11-15%22&wt=xml
		-->
		<p:load>
			<p:with-option name="href" select="
				concat(
					$solr-base-uri, 
					'select?wt=xml&amp;fl=id&amp;q=document-identifier%3A%22', 
					encode-for-uri($document-identifier), 
					'%22'
				)
			"/>
		</p:load>
		<!--
		Producing a result like:
		<response>
			<lst name="responseHeader">
			  <int name="status">0</int>
			  <int name="QTime">1</int>
			  <lst name="params">
				<str name="q">document-identifier:"57-11-15"</str>
				<str name="fl">id</str>
				<str name="wt">xml</str>
				<str name="_">1661773439985</str>
			  </lst>
			</lst>
			<result name="response" numFound="1" start="0" numFoundExact="true">
			  <doc>
				<str name="id">Mueller%20letters/1850-9/1857/57-11-15-final</str></doc>
			</result>
		</response>
		... and returning an HTTP redirect to an HTML page based on the "id" result
		-->
		<p:choose>
			<p:when test="/response/result/doc/str[@name='id']">
				<p:template name="redirect">
					<p:input port="parameters"><p:empty/></p:input>
					<p:input port="template">
						<p:inline>
							<c:response status="303">
								<c:header name="Location" value="/text/{/response/result/doc/str[@name='id'][1]}/"/>
							</c:response>
						</p:inline>
					</p:input>
				</p:template>
			</p:when>
			<p:otherwise>
				<chymistry:id-unresolved/>
			</p:otherwise>
		</p:choose>
	</p:declare-step>
	
	<p:declare-step type="chymistry:id-unresolved">
		<p:input port="source"/>
		<p:output port="result"/>
		<p:identity>
			<p:input port="source">
				<p:inline>
					<c:response status="404">
						<c:header name="X-Powered-By" value="XProc using XML Calabash"/>
						<c:header name="Server" value="XProc-Z"/>
						<c:body content-type="application/xhtml+xml">
							<html xmlns="http://www.w3.org/1999/xhtml">
								<head>
									<title>Text not found</title>
								</head>
								<body>
									<main>
									<h1>Text not found</h1>
									<p>The text you requested was not found.</p>
									<p> The corpus is still being edited. Letters in draft, or proofed waiting final editing, will not appear. 
									The text you requested may be one of these, and will appear here when finally edited.    </p>
									</main>
								</body>
							</html>
						</c:body>
					</c:response>
				</p:inline>
			</p:input>
		</p:identity>
	</p:declare-step>
	
	<p:declare-step name="search" type="chymistry:search">
		<p:input port="source"/>
		<p:output port="result"/>
		<p:option name="solr-base-uri" required="true"/>
		<p:variable name="default-results-limit" select="50"/>
		<p:choose>
			<p:when test="/c:request/@method='GET'">
				<p:www-form-urldecode name="field-values">
					<p:with-option name="value" select="substring-after(/c:request/@href, '?')"/>
				</p:www-form-urldecode>
				<p:load name="field-definitions" href="../search-fields.xml"/>
				<p:wrap-sequence name="field-definitions-and-values" wrapper="search">
					<p:input port="source">
						<p:pipe step="field-definitions" port="result"/>
						<p:pipe step="field-values" port="result"/>
					</p:input>
				</p:wrap-sequence>
				<p:xslt name="prepare-solr-request">
					<p:with-param name="solr-base-uri" select="$solr-base-uri"/>
					<p:with-param name="default-results-limit" select="$default-results-limit"/>
					<p:input port="stylesheet"><p:document href="../xslt/search-parameters-to-solr-request.xsl"/></p:input>
				</p:xslt>
				<!--
				<z:dump href="../debug/solr-request.xml"/>
				-->
				<p:xslt name="convert-xml-to-json">
					<p:input port="parameters"><p:empty/></p:input>
					<p:input port="stylesheet"><p:document href="../xslt/convert-between-xml-and-json.xsl"/></p:input>
				</p:xslt>
				<p:http-request/>
				<p:xslt name="convert-json-to-xml">
					<p:input port="parameters"><p:empty/></p:input>
					<p:input port="stylesheet"><p:document href="../xslt/convert-between-xml-and-json.xsl"/></p:input>
				</p:xslt>
				<p:wrap-sequence name="request-and-response" wrapper="request-and-reponse">
					<p:input port="source">
						<p:pipe step="field-values" port="result"/>
						<p:pipe step="convert-json-to-xml" port="result"/>
						<p:pipe step="field-definitions" port="result"/>
					</p:input>
				</p:wrap-sequence>
				<!-- TODO keep this but control it by some kind of debugging configuration flag -->
				<!--
				<z:dump href="../debug/search-request-response-and-config.xml"/>
				-->
				<p:xslt name="render-solr-response">
					<p:with-param name="default-results-limit" select="$default-results-limit"/>
					<!--<p:input port="source"><p:pipe step="request-and-response" port="result"/></p:input>-->
					<p:input port="stylesheet"><p:document href="../xslt/solr-response-to-html.xsl"/></p:input>
				</p:xslt>
				<z:make-http-response content-type="text/html"/>
			</p:when>
			<p:when test="/c:request/@method='POST'">
				<!-- The search form uses POST to send search parameters both in the POST body and as URL query parameters. -->
				<!-- This is so that the facet value selection buttons (which are submit buttons) can each have their own target URLs, -->
				<!-- which include parameters already. -->
				<!-- This sub-pipeline extracts the parameters from the request URL and the POST body, re-encodes them all as URL -->
				<!-- query parameters (discarding those with empty values), and redirects the user  to the resulting URL. -->
				<p:variable name="filtered-parameters" select="
					string-join(
						for $parameter in (
							tokenize(
								substring-after(/c:request/@href, '?'), 
								'&amp;'
							),
							tokenize(
								normalize-space(/c:request/c:body), 
								'&amp;'
							)
						) return if (ends-with($parameter, '=')) then () else $parameter,
						'&amp;'
					)
				"/>
				<p:template name="redirect">
					<p:with-param name="parameters" select="$filtered-parameters"/>
					<p:input port="template">
						<p:inline>
							<c:response status="303">
								<c:header name="Location" value="{
									concat(
										'/search/?',
										$parameters
									)
								}"/>
							</c:response>
						</p:inline>
					</p:input>
				</p:template>
			</p:when>
		</p:choose>
	</p:declare-step>
	
</p:library>
