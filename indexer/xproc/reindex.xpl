<p:declare-step version="1.0"
           xmlns:p="http://www.w3.org/ns/xproc"
           xmlns:c="http://www.w3.org/ns/xproc-step"
           xmlns:z="https://github.com/Conal-Tuohy/XProc-Z"
           xmlns:l="http://xproc.org/library"
           xmlns:chymistry="tag:conaltuohy.com,2018:chymistry"
           xmlns:cx="http://xmlcalabash.com/ns/extensions"
            name="reindex" type="chymistry:reindex">

        <p:import href="http://xmlcalabash.com/extension/steps/library-1.0.xpl"/>
        <!--<p:import href="xproc-z-library.xpl"/>-->
        <p:import href="recursive-directory-list.xpl"/>

        <p:output port="result"/>
        <p:option name="solr-base-uri" required="true"/>
        <p:option name="corpus-base-uri" required="true"/>
        <p:option name="search-fields" required="true"/>
        <!-- reindex all the P5 files -->


    <p:declare-step name="generate-indexer" type="chymistry:generate-indexer">
        <p:output port="result"/>
        <p:option name="solr-base-uri" required="true"/>
        <p:option name="search-fields" required="true"/>
        <p:load name="search-fields">
            <p:with-option name="href" select="$search-fields"/>
        </p:load>
        <p:xslt>
            <p:with-param name="solr-base-uri" select="$solr-base-uri"/>
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
        <!--<z:make-http-response content-type="application/xml"/>-->
    </p:declare-step>

    <p:declare-step name="convert-p5-to-solr" type="chymistry:convert-p5-to-solr">
        <p:input port="source"/>
        <p:output port="result"/>
        <p:option name="solr-base-uri" required="true"/>
        <p:option name="search-fields" required="true"/>
        <p:option name="href" required="true"/>
        <p:option name="id" required="true"/>
        <chymistry:generate-indexer name="indexing-stylesheet">
            <p:with-option name="solr-base-uri" select="$solr-base-uri"/>
            <p:with-option name="search-fields" select="$search-fields"/>
        </chymistry:generate-indexer>
        <!--<chymistry:p5-text name="text">
            <p:with-option name="href" select="$href"/>
        </chymistry:p5-text>-->
        <p:load name="text">
            <p:with-option name="href" select="$href"/>
        </p:load>
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
                <p:document href="/var/lib/xproc-z-app/xslt/p5-to-html.xsl"/>
            </p:input>
        </p:xslt>
        <p:xslt name="normalized-field">
            <p:with-param name="field-name" select=" 'normalized' "/>
            <p:input port="stylesheet">
                <p:document href="../xslt/html-to-solr-field.xsl"/>
            </p:input>
        </p:xslt>
        <!-- generate an HTML summary of the P5 text, serialized into a Solr field -->
        <!--
        NOT USED IN VMCP because the teiHeader-derived "document information" panel is just part of the main text of
        the page and accessible via the main Solr 'text' field.
        -->
        <!--
        <p:xslt name="metadata-summary-field">
            <p:input port="parameters"><p:empty/></p:input>
            <p:input port="source">
                <p:pipe step="text" port="result"/>
            </p:input>
            <p:input port="stylesheet">
                <p:document href="../xslt/metadata-summary-as-solr-field.xsl"/>
            </p:input>
        </p:xslt>
        -->
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
                <!--
                NOT USED IN VMCP because the teiHeader-derived "document information" panel is just part of the main text of
                the page and accessible via the main Solr 'text' field.
                <p:pipe step="metadata-summary-field" port="result"/>
                -->
            </p:input>
        </p:insert>
    </p:declare-step>


    <!-- TODO: replace this step with one which purges documents older than a certain timestamp, and
    invoke it after the reindex has taken place. That would purge any documents which had been
    withdrawn from publication -->
    <p:declare-step name="purge-index" type="chymistry:purge-index">
        <!--<p:input port="source"/>-->
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
        <!--
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
        <z:make-http-response content-type="text/html"/>-->
    </p:declare-step>
    <p:try name="process-directory">
        <p:group>
            <cx:message>
                <p:with-option name="message" select="concat('corpus base uri=', $corpus-base-uri)"/>
                <p:input port="source"><p:empty/></p:input>
            </cx:message>
            <!-- ignore directories whose names begin with a "." such as e.g. ".git" -->
            <l:recursive-directory-list name="list-p5-files" exclude-filter="^\..*">
                <p:with-option name="path" select="$corpus-base-uri" />
            </l:recursive-directory-list>
            <p:add-xml-base name="add-xml-base" relative="false" all="true"/>
            <p:for-each>
                <p:iteration-source select="//c:file[ends-with(@name, '.xml')]"/>
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
                    <p:with-option name="search-fields" select="$search-fields"/>
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
    <!--
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
    -->
</p:declare-step>