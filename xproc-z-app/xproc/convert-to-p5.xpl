<p:library version="1.0"
	xmlns:p="http://www.w3.org/ns/xproc" 
	xmlns:c="http://www.w3.org/ns/xproc-step" 
	xmlns:z="https://github.com/Conal-Tuohy/XProc-Z" 
	xmlns:fn="http://www.w3.org/2005/xpath-functions"
	xmlns:xi="http://www.w3.org/2001/XInclude"
	xmlns:chymistry="tag:conaltuohy.com,2018:chymistry"
	xmlns:tei="http://www.tei-c.org/ns/1.0"
	xmlns:cx="http://xmlcalabash.com/ns/extensions">
	
	<p:import href="http://xmlcalabash.com/extension/steps/library-1.0.xpl"/>
	<p:import href="xproc-z-library.xpl"/>
	
	<p:declare-step name="download-source" type="chymistry:download-source">
		<p:input port="source"/>
		<p:output port="result"/>
		<!-- TODO: decide if we need this; it would simply need to do a git update on the acsproj git repository -->
		<z:make-http-response content-type="application/xml"/>
	</p:declare-step>
	
	<p:declare-step name="regularize-tei" type="chymistry:regularize-tei">
		<p:input port="source"/>
		<p:output port="result"/>
		<p:xslt>
			<p:input port="parameters"><p:empty/></p:input>
			<p:input port="stylesheet">
				<p:document href="../xslt/convert-to-p5/regularize-p5.xsl"/>
			</p:input>
		</p:xslt>
	</p:declare-step>
	
	
	<!-- remove old schema assignment and add a new one -->
	<p:declare-step name="assign-schema" type="chymistry:assign-schema">
		<p:input port="source"/>
		<p:output port="result"/>
		<p:option name="schema" required="true"/>
		<p:xslt>
			<p:with-param name="schema" select="$schema"/>
			<p:input port="stylesheet">
				<p:document href="../xslt/assign-schema.xsl"/>
			</p:input>
		</p:xslt>
	</p:declare-step>
	
	<p:declare-step type="chymistry:insert-glossary-xinclude">
		<p:input port="source"/>
		<p:output port="result"/>
		<p:insert match="/tei:TEI/tei:teiHeader" position="after">
			<p:input port="insertion">
				<p:inline xmlns="http://www.tei-c.org/ns/1.0" exclude-inline-prefixes="#all">
					<standOff>
						<xi:include href="swinburneGlossary.xml" xpointer="xmlns(tei=http://www.tei-c.org/ns/1.0) xpath(tei:TEI/tei:text/tei:body/tei:div/tei:entry)"/>
					</standOff>
				</p:inline>
			</p:input>
		</p:insert>
	</p:declare-step>
	
	<p:declare-step type="chymistry:declare-reference-systems">
		<p:input port="source"/>
		<p:output port="result"/>
		<!-- insert declaration of the reference systems (i.e. pointer schemes) used in the corpus -->
		<p:insert name="empty-encoding-desc" match="tei:teiHeader[not(tei:encodingDesc)]/tei:fileDesc" position="after">
			<p:input port="insertion">
				<p:inline xmlns="http://www.tei-c.org/ns/1.0" exclude-inline-prefixes="#all">
					<encodingDesc/>
				</p:inline>
			</p:input>
		</p:insert>
		<p:insert name="listPrefixDef" match="tei:encodingDesc" position="first-child">
			<p:input port="insertion">
				<p:inline exclude-inline-prefixes="#all">
					<xi:include href="includes/listPrefixDef.xml"/>
				</p:inline>
			</p:input>  
		</p:insert>
	</p:declare-step>
	
	<p:declare-step type="chymistry:insert-authority-xinclude">
		<p:input port="source"/>
		<p:output port="result"/>
		<!-- insert subsidiary material; bibliographies, personographies, gazeteers, etc. -->
		<!-- ensure the document has a profileDesc containing a particDesc, to insert into -->
		<p:identity name="leave-until-topicmap-derived-tei-is-valid"/><!-- TODO re-enable this when XTM conversion done -->
		<p:insert name="empty-encoding-desc" match="tei:teiHeader[not(tei:encodingDesc)]/tei:fileDesc" position="after">
			<p:input port="insertion">
				<p:inline xmlns="http://www.tei-c.org/ns/1.0" exclude-inline-prefixes="#all">
					<encodingDesc/>
				</p:inline>
			</p:input>
		</p:insert>
		<p:insert name="empty-class-decl" match="tei:teiHeader/tei:encodingDesc" position="first-child">
			<p:input port="insertion">
				<p:inline xmlns="http://www.tei-c.org/ns/1.0" exclude-inline-prefixes="#all">
					<classDecl/>
				</p:inline>
			</p:input>
		</p:insert>
		<p:insert name="taxonomy" match="tei:classDecl" position="first-child">
			<p:input port="insertion">
				<p:inline exclude-inline-prefixes="#all">
					<xi:include href="authority.xml" xpointer="xmlns(tei=http://www.tei-c.org/ns/1.0) xpath(/tei:TEI/tei:teiHeader/tei:encodingDesc/tei:classDecl/tei:taxonomy)"/>
				</p:inline>
			</p:input>  
		</p:insert>
		<p:insert name="authority-lists" match="tei:sourceDesc" position="first-child">
			<p:input port="insertion">
				<p:inline exclude-inline-prefixes="#all">
					<xi:include href="authority.xml" xpointer="
						xmlns(tei=http://www.tei-c.org/ns/1.0) 
						xpath(
							/tei:TEI/tei:text/tei:body/tei:div/tei:listBibl | 
							/tei:TEI/tei:text/tei:body/tei:div/tei:listPerson | 
							/tei:TEI/tei:text/tei:body/tei:div/tei:listOrg | 
							/tei:TEI/tei:text/tei:body/tei:div/tei:listEvent | 
							/tei:TEI/tei:text/tei:body/tei:div/tei:listPlace
						)
					"/>
				</p:inline>
			</p:input>
		</p:insert>
	</p:declare-step>
	
	<p:declare-step name="extract-hierarchy" type="chymistry:extract-hierarchy">
		<p:input port="source"/>
		<p:output port="result"/>
		<p:documentation>
			Bring the hierarchical structure, already encoded in the index[@indexName='nav'] elements,
			into the teiHeader of the TEI documents which contain the volumes, so that when the small 
			text-level documents are generated, they can have a copy of the full volume hierarchy, for 
			display as a table of contents.
		</p:documentation>
		<p:xslt>
			<p:input port="parameters"><p:empty/></p:input>
			<p:input port="stylesheet">
				<p:document href="../xslt/convert-to-p5/generate-bibl-hierarchy.xsl"/>
			</p:input>
		</p:xslt>
	</p:declare-step>
	
</p:library>
