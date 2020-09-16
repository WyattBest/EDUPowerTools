<?xml version="1.0" encoding="UTF-8" standalone="no"?>
<xsl:stylesheet version="1.0" xmlns="http://www.w3.org/1999/XSL/Transform" 
                xmlns:diffgr="urn:schemas-microsoft-com:xml-diffgram-v1" 
                xmlns:xsl="http://www.w3.org/1999/XSL/Transform" 
                xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
  <xsl:output method="text" />
  <xsl:template match="/">
    <xsl:apply-templates/>
  </xsl:template>
  <xsl:template match="DataSet/diffgr:diffgram/DynamicForms">
    <xsl:for-each select="DynamicForm">
      <xsl:value-of select=" zNGImageName "/>
      <xsl:value-of select="','"/>
      <xsl:value-of select="PEOPLE_CODE_ID"/>
      <xsl:value-of select="','"/>
      <xsl:value-of select="EmailAddress"/>
      <xsl:text>&#xD;&#xA;</xsl:text>
    </xsl:for-each>
  </xsl:template>
</xsl:stylesheet>
