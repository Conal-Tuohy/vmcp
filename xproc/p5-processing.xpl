<p:library version="1.0" 
	xmlns:p="http://www.w3.org/ns/xproc" 
	xmlns:c="http://www.w3.org/ns/xproc-step" 
	xmlns:z="https://github.com/Conal-Tuohy/XProc-Z" 
	xmlns:fn="http://www.w3.org/2005/xpath-functions"
	xmlns:l="http://xproc.org/library"
	xmlns:chymistry="tag:conaltuohy.com,2018:chymistry"
	xmlns:cx="http://xmlcalabash.com/ns/extensions"
	xmlns:tei="http://www.tei-c.org/ns/1.0">
	
	<p:import href="http://xmlcalabash.com/extension/steps/library-1.0.xpl"/>
	<p:import href="xproc-z-library.xpl"/>
	<p:import href="recursive-directory-list.xpl"/>
	
	<p:declare-step name="update-schema" type="chymistry:update-schema">
		<p:input port="source"/>
		<p:output port="result"/>
		<p:option name="solr-base-uri" required="true"/>
		<p:template name="query-for-current-solr-schema">
			<p:with-param name="solr-base-uri" select="$solr-base-uri"/>
			<p:input port="template">
				<p:inline>
					<c:request method="get" href="{$solr-base-uri}schema?wt=xml">
						<c:header name="Accept" value="application/xml"/>
					</c:request>
				</p:inline>
			</p:input>
		</p:template>
		<p:http-request name="current-solr-schema"/>
		<p:wrap-sequence name="current-solr-schema-and-new-search-fields" wrapper="current-solr-schema-and-new-search-fields">
			<p:input port="source">
				<p:pipe step="current-solr-schema" port="result"/>
				<p:document href="../search-fields.xml"/>
			</p:input>
		</p:wrap-sequence>
		<!-- transform to a Solr schema API update request (either updating, or adding each field, as appropriate), make request, format result -->
		<p:xslt name="prepare-schema-update-request">
			<p:with-param name="solr-base-uri" select="$solr-base-uri"/>
			<p:input port="stylesheet">
				<p:document href="../xslt/update-schema-from-field-definitions.xsl"/>
			</p:input>
		</p:xslt>
		<p:http-request name="update-schema-in-solr"/>
		<!-- debug the Solr schema API interaction -->
		<!-- TODO keep this but control it by some kind of debugging configuration flag -->
		<!--
		<p:group name="debug-schema-update">
			<p:wrap-sequence wrapper="current-schema-and-update-message-and-result">
				<p:input port="source">
					<p:pipe step="current-solr-schema" port="result"/>
					<p:pipe step="prepare-schema-update-request" port="result"/>
					<p:pipe step="update-schema-in-solr" port="result"/>
				</p:input>
			</p:wrap-sequence>
			<p:store href="../debug/schema-update.xml"/>
		</p:group>
		-->
		<z:make-http-response>
			<p:input port="source">
				<p:pipe step="update-schema-in-solr" port="result"/>
			</p:input>
		</z:make-http-response>
	</p:declare-step>
	
<!-- for request URI "admin/purge", clear the Solr index -->
	<p:declare-step name="purge-index" type="chymistry:purge-index">
		<p:input port="source"/>
		<p:output port="result"/>
		<p:option name="solr-base-uri" required="true"/>
		<!-- generate the HTTP POST command to purge Solr's index -->
		<p:add-attribute name="solr-purge-command" match="/c:request" attribute-name="href">
			<p:with-option name="attribute-value" select="concat($solr-base-uri, 'update?commit=true')"/>
			<p:input port="source">
				<p:inline>
					<c:request method="post">
						<c:body content-type="text/xml">
							<delete>
								<query>*:*</query>
							</delete>
						</c:body>
					</c:request>
				</p:inline>
			</p:input>
		</p:add-attribute>
		<!-- submit the deletion request to Solr -->
		<p:http-request/>
		<!-- convert Solr response to a friendly HTML page -->
		<p:template name="purge-report">
			<p:with-param name="response-code" select="/response/lst[@name='responseHeader']/int[@name='status']/text()"/>
			<p:input port="template">
				<p:inline>
					<html xmlns="http://www.w3.org/1999/xhtml">
						<head><title>Solr index purge</title></head>
						<body>
							<section class="content">
								<div>
									<h1>Solr index purge</h1>
									<p>
									{
										if ($response-code='0') then 
											'Solr index purged' 
										else 
											concat(
												'Failed to purge Solr index. ',
												if ($response-code) then
													concat(
														'Solr returned response code ', 
														$response-code
													)
												else
													''
											)
									}
									</p>
									<p><a href="../admin">Return to admin page</a></p>
								</div>
							</section>
						</body>
					</html>
				</p:inline>
			</p:input>
		</p:template>
		<z:make-http-response content-type="text/html"/>
	</p:declare-step>

	<p:declare-step name="create-xinclude-fallbacks" type="chymistry:create-xinclude-fallbacks">
		<p:input port="source"/>
		<p:output port="result"/>
		<p:xslt>
			<p:input port="parameters"><p:empty/></p:input>
			<p:input port="stylesheet">
				<p:document href="../xslt/insert-xinclude-fallbacks.xsl"/>
			</p:input>
		</p:xslt>
	</p:declare-step>
					
	<p:declare-step name="reindex" type="chymistry:reindex">
		<p:input port="source"/>
		<p:output port="result"/>
		<p:option name="solr-base-uri" required="true"/>
		<p:option name="corpus-base-uri" required="true"/>
		<!-- reindex all the P5 files -->
		<p:try>
			<p:group name="process-directory">
				<cx:message>
					<p:with-option name="message" select="concat('corpus base uri=', $corpus-base-uri)"/>
				</cx:message>
				<l:recursive-directory-list name="list-p5-files">
					<p:with-option name="path" select="$corpus-base-uri"/>
				</l:recursive-directory-list>
				<p:add-xml-base name="add-xml-base" relative="false" all="true"/>
				<p:for-each>
					<p:iteration-source select="//c:file"/>
					<p:variable name="file-name" select="/c:file/@name"/>
					<p:variable name="file-relative-uri" select="encode-for-uri($file-name)"/>
					<p:variable name="file-absolute-uri" select="resolve-uri($file-relative-uri, /c:file/@xml:base)"/>
					<p:variable name="counter" select="p:iteration-position()"/>
					<!-- compute an identifier for the document to use in Solr:
						get the URI of the XML document relative to the corpus root folder, 
						strip off the '.xml' extension
					-->
					<p:variable name="file-id" select="substring-before(substring-after($file-absolute-uri, $corpus-base-uri), '.xml')"/>
					<chymistry:convert-p5-to-solr>
						<p:with-option name="solr-base-uri" select="$solr-base-uri"/>
						<p:with-option name="href" select="$file-absolute-uri"/>
						<p:with-option name="id" select="$file-id"/>
					</chymistry:convert-p5-to-solr>
					<!--
					<z:dump>
						<p:with-option name="href" select="concat('/tmp/index/', $counter, '.xml')"/>
					</z:dump>
					<cx:message>
						<p:with-option name="message" select="
							concat(
								'indexing ', 
								$file-absolute-uri,
								' operation=',
								local-name(/c:request/c:body/*)
							)
						"/>
					</cx:message>
					-->
					<p:http-request/>
				</p:for-each>
			</p:group>
			<p:catch name="process-directory-caught-error">
				<p:identity>
					<p:input port="source">
						<p:pipe step="process-directory-caught-error" port="error"/>
					</p:input>
				</p:identity>
			</p:catch>
		</p:try>
		<p:wrap-sequence wrapper="solr-index-responses"/>
		<p:xslt name="render-reindexing-report">
			<p:input port="parameters"><p:empty/></p:input>
			<p:input port="stylesheet">
				<p:inline>
					<xsl:stylesheet version="3.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform" 
						xmlns:c="http://www.w3.org/ns/xproc-step" 
						xmlns="http://www.w3.org/1999/xhtml"
						expand-text="yes">
						<xsl:template match="/">
							<html>
								<head><title>Solr Reindex</title></head>
								<body>
									<h1>Solr Reindex</h1>
									<xsl:choose>
										<xsl:when test="solr-index-responses/c:errors">
											<p>Solr indexing failed.</p>
											<table>
												<thead>
													<tr><th>Error message</th><th>Error code</th><th>File</th><th>Line</th><th>Column</th></tr>
												</thead>
												<tbody>
													<xsl:for-each select="solr-index-responses/c:errors/c:error">
														<tr>
															<td>{.}</td><td>{@code}</td><td>{@href}</td><td>{@line}</td><td>{@column}</td>
														</tr>
													</xsl:for-each>
												</tbody>
											</table>
										</xsl:when>
										<xsl:otherwise>
											<p>Solr indexing succeeded.</p>
											<p>Indexed {count(//int[@name='status'][.='0'])} documents in {sum(//int[@name='QTime'])} ms.</p>
										</xsl:otherwise>
									</xsl:choose>
								</body>
							</html>
						</xsl:template>
					</xsl:stylesheet>
				</p:inline>
			</p:input>
		</p:xslt>
		<z:make-http-response/>
	</p:declare-step>
	
	<p:declare-step name="generate-indexer" type="chymistry:generate-indexer">
		<p:output port="result"/>
		<p:option name="solr-base-uri" required="true"/>
		<p:xslt>
			<p:with-param name="solr-base-uri" select="$solr-base-uri"/>
			<p:input port="source">
				<p:document href="../search-fields.xml"/>
			</p:input>
			<p:input port="stylesheet">
				<p:document href="../xslt/field-definition-to-solr-indexing-stylesheet.xsl"/>
			</p:input>
		</p:xslt>
	</p:declare-step>
	
	<!-- debugging / testing method; outputs a Solr update message XML verbatim -->
	<p:declare-step name="p5-as-solr" type="chymistry:p5-as-solr">
		<p:input port="source"/>
		<p:output port="result"/>
		<p:option name="solr-base-uri" required="true"/>
		<p:option name="corpus-base-uri" required="true"/>
		<p:variable name="file-relative-uri" select="substring-after(/c:request/@href, '/solr/')"/>
		<p:variable name="file-absolute-uri" select="resolve-uri($file-relative-uri, $corpus-base-uri)"/>
		<chymistry:convert-p5-to-solr>
			<p:with-option name="solr-base-uri" select="$solr-base-uri"/>
			<p:with-option name="href" select="$file-absolute-uri"/>
			<p:with-option name="id" select="substring-before($file-relative-uri, '.xml')"/>
		</chymistry:convert-p5-to-solr>
		<z:make-http-response content-type="application/xml"/>
	</p:declare-step>
	
	<p:declare-step name="convert-p5-to-solr" type="chymistry:convert-p5-to-solr">
		<p:input port="source"/>
		<p:output port="result"/>
		<p:option name="solr-base-uri" required="true"/>
		<p:option name="href" required="true"/>
		<p:option name="id" required="true"/>
		<chymistry:generate-indexer name="indexing-stylesheet">
			<p:with-option name="solr-base-uri" select="$solr-base-uri"/>
		</chymistry:generate-indexer>
		<chymistry:p5-text name="text">
			<p:with-option name="href" select="$href"/>
		</chymistry:p5-text>
		<p:xslt name="metadata-fields">
			<p:with-param name="id" select="$id"/>
			<p:with-param name="solr-base-uri" select="$solr-base-uri"/>
			<p:input port="source">
				<p:pipe step="text" port="result"/>
			</p:input>
			<p:input port="stylesheet">
				<p:pipe step="indexing-stylesheet" port="result"/>
			</p:input>
		</p:xslt>
		<p:xslt name="normalized-html">
			<p:input port="parameters"><p:empty/></p:input>
			<p:input port="source">
				<p:pipe step="text" port="result"/>
			</p:input>
			<p:input port="stylesheet">
				<p:document href="../xslt/p5-to-html.xsl"/>
			</p:input>
		</p:xslt>
		<p:xslt name="normalized-field">
			<p:with-param name="field-name" select=" 'normalized' "/>
			<p:input port="stylesheet">
				<p:document href="../xslt/html-to-solr-field.xsl"/>
			</p:input>
		</p:xslt>
		<!-- generate an HTML summary of the P5 text, serialized into a Solr field -->
		<p:xslt name="metadata-summary-field">
			<p:input port="parameters"><p:empty/></p:input>
			<p:input port="source">
				<p:pipe step="text" port="result"/>
			</p:input>
			<p:input port="stylesheet">
				<p:document href="../xslt/metadata-summary-as-solr-field.xsl"/>
			</p:input>
		</p:xslt>
		<p:insert name="insert-text-fields" match="doc" position="last-child">
			<p:input port="source">
				<p:pipe step="metadata-fields" port="result"/>
			</p:input>
			<p:input port="insertion">
			<!--
				<p:pipe step="introduction-field" port="result"/>
				<p:pipe step="diplomatic-field" port="result"/>
				-->
				<p:pipe step="normalized-field" port="result"/>
				<p:pipe step="metadata-summary-field" port="result"/>
			</p:input>
		</p:insert>
	</p:declare-step>	
	
	<p:declare-step name="p5-as-iiif" type="chymistry:p5-as-iiif">
		<p:input port="source"/>
		<p:output port="result"/>
		<p:option name="corpus-base-uri" required="true"/>
		<p:variable name="base-uri" select="concat(substring-before(/c:request/@href, '/iiif/'), '/iiif/')"/>
		<p:variable name="text-id" select="substring-before(substring-after(/c:request/@href, '/iiif/'), '/')"/>
		<p:variable name="file-relative-uri" select="concat(substring-before(substring-after(/c:request/@href, '/iiif/'), '/manifest'), '.xml')"/>
		<p:variable name="file-absolute-uri" select="resolve-uri($file-relative-uri, $corpus-base-uri)"/>
		<chymistry:p5-text>
			<p:with-option name="href" select="$file-absolute-uri"/>
		</chymistry:p5-text>
		<p:xslt>
			<p:with-param name="base-uri" select="$base-uri"/>
			<p:with-param name="text-id" select="$text-id"/>
			<p:input port="stylesheet">
				<p:document href="../xslt/p5-to-iiif-manifest.xsl"/>
			</p:input>
		</p:xslt>
		<p:xslt>
			<p:input port="parameters"><p:empty/></p:input>
			<p:input port="stylesheet">
				<p:document href="../xslt/xml-to-json.xsl"/>
			</p:input>
		</p:xslt>
	</p:declare-step>
	
	<p:declare-step name="iiif-annotation-list" type="chymistry:iiif-annotation-list">
		<p:documentation>
			Generates a IIIF annotation list for a particular folio (IIIF Canvas), consisting of links to the related page of transcription,
			in both a diplomatic and a normalized form.
		</p:documentation>
		<p:input port="source"/>
		<p:output port="result"/>
		<!-- request URI something like http://localhost:8080/iiif/ALCH00001/list/folio-3v -->
		<p:variable name="base-uri" select="concat(substring-before(/c:request/@href, '/iiif/'), '/')"/>
		<p:variable name="text-id" select="substring-before(substring-after(/c:request/@href, '/iiif/'), '/')"/>
		<p:variable name="folio-id" select="
			substring-after(
				substring-after(
					/c:request/@href, 
					'/iiif/'
				), 
				'/list/'
			)
		"/>
		<chymistry:p5-text>
			<p:with-option name="text" select="$text-id"/>
		</chymistry:p5-text>
		<p:xslt>
			<p:with-param name="base-uri" select="$base-uri"/>
			<p:with-param name="text-id" select="$text-id"/>
			<p:with-param name="folio-id" select="$folio-id"/>
			<p:input port="stylesheet">
				<p:document href="../xslt/p5-to-iiif-annotation-list.xsl"/>
			</p:input>
		</p:xslt>
		<p:xslt>
			<p:input port="parameters"><p:empty/></p:input>
			<p:input port="stylesheet">
				<p:document href="../xslt/xml-to-json.xsl"/>
			</p:input>
		</p:xslt>
	</p:declare-step>
	
	<p:declare-step name="bibliography-as-html" type="chymistry:bibliography-as-html">
		<p:input port="source"/>
		<p:output port="result"/>
		<p:load href="../p5/CHYM000001.xml"/>
		<p:xslt>
			<p:input port="parameters"><p:empty/></p:input>
			<p:input port="stylesheet">
				<p:document href="../xslt/bibliography-to-html.xsl"/>
			</p:input>
		</p:xslt>
		<z:make-http-response content-type="text/html"/>
	</p:declare-step>

	<p:declare-step name="p5-as-html" type="chymistry:p5-as-html" xmlns:tei="http://www.tei-c.org/ns/1.0">
		<p:input port="source"/>
		<p:output port="result"/>
		<p:input port="parameters" kind="parameter" primary="true"/>
		<p:option name="href" required="true"/>
		<p:option name="base-uri" required="true"/>
		<p:parameters name="configuration">
			<p:input port="parameters">
				<p:pipe step="p5-as-html" port="parameters"/>
			</p:input>
		</p:parameters>
		<chymistry:p5-text>
			<p:with-option name="href" select="$href"/>
		</chymistry:p5-text>
		<p:xslt name="text-as-html">
			<p:with-param name="google-api-key" select="/c:param-set/c:param[@name='google-api-key']/@value">
				<p:pipe step="configuration" port="result"/>
			</p:with-param>
			<p:input port="stylesheet">
				<p:document href="../xslt/p5-to-html.xsl"/>
			</p:input>
		</p:xslt>
		<z:make-http-response content-type="text/html"/>
	</p:declare-step>
	
	<p:declare-step name="p5-as-xml" type="chymistry:p5-as-xml">
		<p:input port="source"/>
		<p:output port="result"/>
		<p:option name="corpus-base-uri" required="true"/>
		<p:variable name="file-relative-uri" select="substring-after(/c:request/@href, '/p5/')"/>
		<p:variable name="file-absolute-uri" select="resolve-uri($file-relative-uri, $corpus-base-uri)"/>
		<chymistry:p5-text name="text">
			<p:with-option name="href" select="$file-absolute-uri"/>
		</chymistry:p5-text>
		<z:make-http-response content-type="application/xml"/>
	</p:declare-step>
	
	<p:declare-step name="p5-text" type="chymistry:p5-text">
		<!-- loads and normalizes a P5 text ready to be converted into other formats -->
		<p:output port="result"/>
		<p:option name="href" required="true"/>
		<p:load name="text">
			<p:with-option name="href" select="$href"/>
		</p:load>
		<p:xslt name="recognise-figure-filenames">
			<p:input port="parameters"><p:empty/></p:input>
			<p:input port="stylesheet">
				<p:document href="../xslt/recognise-figure-filenames.xsl"/>
			</p:input>
		</p:xslt>
		<p:xslt name="recognise-document-filenames">
			<p:input port="parameters"><p:empty/></p:input>
			<p:input port="stylesheet">
				<p:document href="../xslt/recognise-document-filenames.xsl"/>
			</p:input>
		</p:xslt>
		<p:xslt name="purge-extraneous-word-and-xtf-content">
			<p:input port="parameters"><p:empty/></p:input>
			<p:input port="stylesheet">
				<p:document href="../xslt/purge-extraneous-word-and-xtf-content.xsl"/>
			</p:input>
		</p:xslt>
		<p:xslt name="renumber-footnotes">
			<p:input port="parameters"><p:empty/></p:input>
			<p:input port="stylesheet">
				<p:document href="../xslt/renumber-footnotes.xsl"/>
			</p:input>
		</p:xslt>
		<p:xslt name="mark-up-translations">
			<p:input port="parameters"><p:empty/></p:input>
			<p:input port="stylesheet">
				<p:document href="../xslt/mark-up-translations.xsl"/>
			</p:input>
		</p:xslt>
		<p:xslt name="trim-white-space-elements">
			<p:input port="parameters"><p:empty/></p:input>
			<p:input port="stylesheet">
				<p:document href="../xslt/trim-white-space-elements.xsl"/>
			</p:input>
		</p:xslt>
	</p:declare-step>
	
	<p:declare-step name="list-p5" type="chymistry:list-p5">
		<p:input port="source"/>
		<p:output port="result"/>
		<p:option name="corpus-base-uri" required="true"/>
		<l:recursive-directory-list name="list-p5-files">
			<p:with-option name="path" select="$corpus-base-uri"/>
		</l:recursive-directory-list>
		<p:add-xml-base name="add-xml-base" relative="false" all="true"/>
		<p:xslt>
			<p:with-param name="corpus-base-uri" select="$corpus-base-uri"/>
			<p:input port="stylesheet">
				<p:document href="../xslt/html-directory-listing.xsl"/>
			</p:input>
		</p:xslt>
		<z:make-http-response content-type="application/xhtml+xml"/>
	</p:declare-step>

</p:library>