 <p:declare-step name="update-schema" type="chymistry:update-schema"  version="1.0"
                    xmlns:p="http://www.w3.org/ns/xproc"
                    xmlns:c="http://www.w3.org/ns/xproc-step"
                    xmlns:z="https://github.com/Conal-Tuohy/XProc-Z"
                    xmlns:l="http://xproc.org/library"
                    xmlns:chymistry="tag:conaltuohy.com,2018:chymistry"
                    xmlns:fn="http://www.w3.org/2005/xpath-functions"
                    xmlns:cx="http://xmlcalabash.com/ns/extensions">
        <p:import href="http://xmlcalabash.com/extension/steps/library-1.0.xpl"/>
        <!--<p:import href="xproc-z-library.xpl"/>-->
        <p:import href="recursive-directory-list.xpl"/>
        <!--<p:input port="source"/>-->
        <p:output port="result"/>
        <p:option name="solr-base-uri" required="true"/>
     <p:option name="search-fields" required="true"/>
        <p:template name="query-for-current-solr-schema">
            <p:with-param name="solr-base-uri" select="$solr-base-uri"/>
            <p:input port="source"><p:empty/></p:input>
            <p:input port="template">
                <p:inline>
                    <c:request method="get" href="{$solr-base-uri}schema?wt=xml">
                        <c:header name="Accept" value="application/xml"/>
                    </c:request>
                </p:inline>
            </p:input>
        </p:template>
        <p:http-request name="current-solr-schema"/>
        <p:load name="search-fields">
            <p:with-option name="href" select="$search-fields"/>
        </p:load>
        <p:wrap-sequence name="current-solr-schema-and-new-search-fields" wrapper="current-solr-schema-and-new-search-fields">
            <p:input port="source">
                <p:pipe step="current-solr-schema" port="result"/>
                <p:pipe step="search-fields" port="result"/>
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
        <!--
        <z:make-http-response>
            <p:input port="source">
                <p:pipe step="update-schema-in-solr" port="result"/>
            </p:input>
        </z:make-http-response>
        -->
    </p:declare-step>