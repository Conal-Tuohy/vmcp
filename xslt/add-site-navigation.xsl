<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="3.0" 
	xmlns:fn="http://www.w3.org/2005/xpath-functions" 
	xmlns="http://www.w3.org/1999/xhtml" 
	xmlns:map="http://www.w3.org/2005/xpath-functions/map"
	xpath-default-namespace="http://www.w3.org/1999/xhtml"
	exclude-result-prefixes="fn map"
	 expand-text="true">
	<!-- embed the page in global navigation -->
	<xsl:param name="current-uri"/>
	<xsl:variable name="menus" select="json-to-xml(unparsed-text('../menus.json'))"/>
	
	<xsl:mode on-no-match="shallow-copy"/>
	
	<!-- insert link to global CSS, any global <meta> elements belong here too -->
	<xsl:template match="head">
		<xsl:copy>
			<xsl:copy-of select="@*"/>
			<xsl:apply-templates select="*"/>
			<meta charset="utf-8" />
			<meta name="viewport" content="width=device-width, initial-scale=1, shrink-to-fit=no"/>
			<meta name="description" content="The Von Mueller Correspondence Project"/>
			<link href="/css/global.css" rel="stylesheet"/>
		</xsl:copy>
	</xsl:template>
	
	<!-- add a global suffix to every page title -->
	<xsl:template match="title">
		<xsl:copy>
			<xsl:value-of select="concat('The Von Mueller Correspondence Project: ',.)"/>
		</xsl:copy>
	</xsl:template>
	
	<!-- insert boiler plate into the body -->
	<xsl:template match="body">
		<xsl:copy>
			<xsl:apply-templates select="@*"/>
			<!-- masthead -->
			<header>
				
			
				<!-- menus read from menus.json -->
				<nav id="main-nav" class="navbar navbar-expand-md navbar-dark bg-dark">
					<a class="navbar-brand" href="/">VMCP</a>
					<xsl:apply-templates select="$menus" mode="main-menu"/>
				</nav>
			</header>
			<!-- contextual sidebar of the menu to which this page belongs, if any -->
			<xsl:variable name="sub-menu">
				<xsl:call-template name="sub-menu"/>
			</xsl:variable>
			<xsl:choose>
				<xsl:when test="$sub-menu/*">
					<section class="content">
						<xsl:copy-of select="$sub-menu"/>
						<div>
							<xsl:apply-templates select="node()"/>
						</div>
					</section>
				</xsl:when>
				<xsl:otherwise>
					<xsl:apply-templates select="node()"/>
				</xsl:otherwise>
			</xsl:choose>
			<!-- footer -->
			<xsl:call-template name="footer"/>
		</xsl:copy>
	</xsl:template>
	
	<xsl:template name="sub-menu">
		<xsl:message select="concat('current uri = ', $current-uri)"/>
		<xsl:variable name="sub-menu" select="$menus/fn:map/fn:map[fn:string = $current-uri]"/>
		<xsl:if test="$sub-menu">
			<nav class="internal">
				<header><xsl:value-of select="$sub-menu/@key"/></header>
				<ul>
					<xsl:for-each select="$sub-menu/fn:string">
						<a class="dropdown-item" href="{.}"><xsl:if test=". = $current-uri">
							<xsl:attribute name="class">current</xsl:attribute>
						</xsl:if>
						<xsl:value-of select="@key"/></a>
					</xsl:for-each>
				</ul>
			</nav>
		</xsl:if>
	</xsl:template>
	
	<xsl:template match="fn:map" mode="main-menu">
		<ul class="navbar-nav mr-auto">
			<xsl:apply-templates mode="main-menu"/>
		</ul>
	</xsl:template>
	<xsl:template match="fn:string" mode="main-menu">
		<li class="nav-item"><a class="nav-link" href="{.}"><xsl:value-of select="@key"/></a></li>
	</xsl:template>
	<xsl:template match="fn:map[ancestor::fn:map]/fn:string" mode="main-menu">
		<a class="dropdown-item" href="{.}"><xsl:value-of select="@key"/></a>
	</xsl:template>
	<xsl:template match="fn:map/fn:map" mode="main-menu">
		<li class="nav-item dropdown">
			<div class="dropdown-menu">
				<xsl:apply-templates mode="main-menu"/>
			</div>
		</li>
	</xsl:template>
	
	<xsl:template name="footer">
		<footer>
			<div>
				<!-- footer content -->
			</div>
		</footer>
	</xsl:template>
		
</xsl:stylesheet>
