<p:library version="1.0" 
	xmlns:p="http://www.w3.org/ns/xproc" 
	xmlns:c="http://www.w3.org/ns/xproc-step" 
	xmlns:z="https://github.com/Conal-Tuohy/XProc-Z" 
	xmlns:l="http://xproc.org/library"
	xmlns:chymistry="tag:conaltuohy.com,2018:chymistry"
	xmlns:fn="http://www.w3.org/2005/xpath-functions"
	xmlns:cx="http://xmlcalabash.com/ns/extensions">
	
	<p:import href="http://xmlcalabash.com/extension/steps/library-1.0.xpl"/>
	<p:import href="xproc-z-library.xpl"/>
	<p:import href="recursive-directory-list.xpl"/>
	
	<p:declare-step name="admin-form" type="chymistry:admin-form">
		<p:input port="source"/>
		<p:output port="result"/>
		<p:identity>
			<p:input port="source">
				<p:inline>
					<c:response status="200">
						<c:body content-type="application/xhtml+xml">
							<html xmlns="http://www.w3.org/1999/xhtml" class="admin">
								<head>
								<title>Administration</title>
								</head>
								<body  class="admin">
								<main role="main" class="admin">
								<div class="container">
								<div class="row">
											<div class="col">
												<h1>Analysis and visualization</h1>
												<p><a href="../p5/">View texts</a></p>
												<h2>Corpus-level summaries</h2>
												<p><a href="/analysis/metadata">Metadata</a></p>
												<p><a href="/analysis/elements">XML elements</a></p>
												<p><a href="/analysis/list-attributes-by-element">XML attributes by element</a></p>
												<p><a href="/analysis/list-classification-attributes">Classification attributes</a></p>
												<p><a href="/analysis/sample-xml-text">Sample XML text</a></p>
											</div>
										</div>
									</div>
									</main>
								</body>
							</html>
						</c:body>
					</c:response>
				</p:inline>
			</p:input>
		</p:identity>
	</p:declare-step>
	
	<p:declare-step name="ingest" type="chymistry:ingest2">
		<p:input port="source"/>
			<p:output port="result"/>
		<p:option name="corpus-base-uri" required="true"/>
			<file:copy name="copy" xmlns:file="http://exproc.org/proposed/steps/file" fail-on-error="false">
				<p:with-option name="href" select=" 'file:/usr/src/xtf/data/tei/Mueller%20letters/1850-9/1858/58-01-07-final.xml' "/>
				<p:with-option name="target" select=" 'file:/etc/xproc-z/vmcp/p5/Mueller%20letters/1850-9/1858/58-01-07-final.xml' "/>
			</file:copy>
		<z:make-http-response content-type="application/xml">
			<p:input port="source">
				<p:pipe step="copy" port="result"/>
			</p:input>
		</z:make-http-response>
	</p:declare-step>
	<p:declare-step name="ingest" type="chymistry:ingest">
		<p:input port="source"/>
		<p:output port="result"/>
		<p:option name="corpus-base-uri" required="true"/>
		<!-- traverse input folders and copy to p5 folder -->
		<l:recursive-directory-list>
			<p:with-option name="path" select="$corpus-base-uri"/>
		</l:recursive-directory-list>
		<p:add-xml-base all="true" relative="false"/>
		<p:viewport match="c:file" name="file">
			<p:output port="result">
				<p:pipe step="copy" port="result"/>
			</p:output>
			<p:variable name="source" select="resolve-uri(encode-for-uri(/c:file/@name), /c:file/@xml:base)"/>
			<p:variable name="target-dir" select="
				concat(
					'../p5/',
					substring-after(
						/c:file/@xml:base, 
						$corpus-base-uri
					)
				)
			"/>
			<p:variable name="target" select="
				resolve-uri(concat($target-dir, encode-for-uri(/c:file/@name)))
			"/>
			<cx:message>
				<p:with-option name="message" select="concat('copy ', $source, ' to ', $target)"/>
			</cx:message>
			<p:try name="copy">
				<p:group>
					<p:output port="result"/>
					<p:load>
						<p:with-option name="href" select="$source"/>
					</p:load>
					<p:store>
						<p:with-option name="href" select="$target"/>
					</p:store>
					<p:identity>
						<p:input port="source">
							<p:pipe step="file" port="current"/>
						</p:input>
					</p:identity>
				</p:group>
				<p:catch name="error">
					<p:output port="result"/>
					<p:identity>
						<p:input port="source">
							<p:pipe step="file" port="current"/>
						</p:input>
					</p:identity>
					<p:insert position="first-child">
						<p:input port="insertion">
							<p:pipe step="error" port="error"/>
						</p:input>
					</p:insert>
				</p:catch>
			</p:try>
		</p:viewport>
		<!-- format result -->
		<p:xslt>
			<p:input port="parameters"><p:empty/></p:input>
			<p:input port="stylesheet"><p:document href="../xslt/source-to-p5-conversion-report.xsl"/></p:input>
		</p:xslt>
		<z:make-http-response content-type="application/xhtml+xml"/>
		<!--
		<z:make-http-response content-type="application/xml"/>
		-->
	</p:declare-step>
</p:library>