USE [Campus6]
GO

/****** Object:  Table [custom].[DialingCodes]    Script Date: 2021-03-29 10:14:34 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE TABLE [custom].[DialingCodes](
	[CountryId] [int] NOT NULL,
	[Prefix] [int] NOT NULL,
	[NumberLength] [int] NOT NULL,
	[Created] [datetime] NOT NULL,
	[Updated] [datetime] NOT NULL
) ON [PRIMARY]
GO

ALTER TABLE [custom].[DialingCodes] ADD  DEFAULT (getdate()) FOR [Created]
GO

ALTER TABLE [custom].[DialingCodes] ADD  DEFAULT (getdate()) FOR [Updated]
GO

