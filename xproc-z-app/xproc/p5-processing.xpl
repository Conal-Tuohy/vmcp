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
		<cx:message>
			<p:with-option name="message" select="
				let $nl := codepoints-to-string(10)
				return
					concat(
						'$corpus-base-uri=', $corpus-base-uri, $nl,
						'$file-relative-uri=', $file-relative-uri, $nl,
						'$file-absolute-uri=', $file-absolute-uri
					)
			"/>
			<p:input port="source"><p:empty/></p:input>
		</cx:message>
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